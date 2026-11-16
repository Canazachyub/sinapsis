import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/estudio_preferencias.dart';
import '../../../courses/domain/entities/course.dart';
import '../../domain/entities/note.dart';
import '../bloc/notes_bloc.dart';
import 'estudio_comodo.dart';
import 'rich_document_editor.dart';

class NoteEditorDialog extends StatefulWidget {
  final Course course;
  final String userId;
  final Note? note;

  const NoteEditorDialog({
    super.key,
    required this.course,
    required this.userId,
    this.note,
  });

  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  final _titleController = TextEditingController();
  final List<String> _tags = [];
  String _content = '';

  /// Modo enfoque: oculta AppBar, título/tags y ayudas (F11 / Esc).
  bool _enfoque = false;

  /// Foco del área de texto: se le devuelve tras alternar el modo enfoque
  /// para que F11 / Esc / Ctrl+S sigan respondiendo sin hacer clic.
  final FocusNode _focoEditor = FocusNode(debugLabel: 'editor-documento');

  /// Nota ya guardada en la base de datos (null = documento nuevo aún no
  /// creado). Tras el primer guardado de un documento nuevo se rellena con la
  /// nota creada, para que los siguientes guardados la ACTUALICEN y no
  /// creen duplicados.
  Note? _nota;

  /// IDs de notas que existían antes de crear este documento (para localizar
  /// la nota creada si la primera espera no la encontró).
  Set<String>? _idsAntesDeCrear;

  /// Hay cambios sin guardar (contenido, título o etiquetas).
  bool _sucio = false;

  /// Hora del último guardado correcto (indicador "Guardado 12:34").
  DateTime? _horaGuardado;
  bool _ultimoFueAutomatico = false;

  /// Guardado en curso (evita guardados simultáneos y duplicados).
  Future<bool>? _guardadoEnCurso;

  /// Se está cerrando a propósito (PopScope deja salir).
  bool _saliendo = false;

  Timer? _temporizadorAutoguardado;
  AppLifecycleListener? _ciclo;

  static const _intervaloAutoguardado = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _nota = widget.note;
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _content = widget.note!.content;
      _tags.addAll(widget.note!.tags);
    }
    // Autoguardado cada 30 s si hay cambios
    _temporizadorAutoguardado = Timer.periodic(_intervaloAutoguardado, (_) {
      if (_sucio) _guardar(automatico: true);
    });
    // Autoguardado al perder el foco la ventana (u ocultarse / cerrarse)
    _ciclo = AppLifecycleListener(
      onInactive: _autoguardarSiHayCambios,
      onHide: _autoguardarSiHayCambios,
      onPause: _autoguardarSiHayCambios,
    );
  }

  @override
  void dispose() {
    _temporizadorAutoguardado?.cancel();
    _ciclo?.dispose();
    _titleController.dispose();
    _focoEditor.dispose();
    super.dispose();
  }

  void _autoguardarSiHayCambios() {
    if (_sucio && mounted && !_saliendo) _guardar(automatico: true);
  }

  void _marcarSucio() {
    if (!_sucio) setState(() => _sucio = true);
  }

  void _alternarEnfoque() {
    setState(() => _enfoque = !_enfoque);
    // El botón pulsado desaparece al cambiar de modo y el foco se perdía:
    // se devuelve al editor para que F11 / Esc respondan sin hacer clic.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focoEditor.requestFocus();
    });
  }

  // ===================== GUARDADO =====================

  /// Guarda el documento. [cerrar]: cierra el editor al terminar (botón
  /// Guardar). [automatico]: autoguardado (sin avisos; si no hay título se
  /// pone uno provisional para no perder el texto).
  Future<bool> _guardar({bool cerrar = false, bool automatico = false}) async {
    final enCurso = _guardadoEnCurso;
    if (enCurso != null) {
      if (automatico) return false;
      await enCurso;
      if (!mounted) return false;
    }
    final futuro = _guardarInterno(cerrar: cerrar, automatico: automatico);
    _guardadoEnCurso = futuro;
    try {
      return await futuro;
    } finally {
      if (identical(_guardadoEnCurso, futuro)) _guardadoEnCurso = null;
    }
  }

  Future<bool> _guardarInterno({required bool cerrar, required bool automatico}) async {
    var titulo = _titleController.text.trim();
    if (titulo.isEmpty) {
      if (!automatico) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor agrega un título')),
        );
        return false;
      }
      if (_content.isEmpty) return false;
      // Autoguardado sin título: título provisional para no perder el texto
      titulo = 'Documento sin título ${DateFormat('dd/MM HH:mm').format(DateTime.now())}';
      _titleController.text = titulo;
    }

    final bloc = context.read<NotesBloc>();
    final contenido = _content;
    final tags = List<String>.from(_tags);

    // Documento nuevo cuyo primer guardado no llegó a identificarse:
    // buscarlo ahora en el estado del bloc antes de crear otro.
    if (_nota == null && _idsAntesDeCrear != null) {
      _nota = _buscarNotaCreada(bloc.state, _idsAntesDeCrear!, null);
    }

    final nota = _nota;
    if (nota == null) {
      final idsPrevios = _idsDeEstado(bloc.state);
      _idsAntesDeCrear = idsPrevios;
      // Suscribirse ANTES de lanzar el evento para no perder la respuesta
      final respuesta = bloc.stream
          .firstWhere((s) => s is NotesLoaded || s is NotesError)
          .timeout(const Duration(seconds: 30));
      bloc.add(CreateNoteEvent(
        courseId: widget.course.id,
        userId: widget.userId,
        title: titulo,
        content: contenido,
        tags: tags,
      ));
      _sucio = false;
      if (cerrar) {
        _cerrar();
        return true;
      }
      try {
        final estado = await respuesta;
        if (estado is NotesError) {
          if (mounted) {
            setState(() => _sucio = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudo guardar: ${estado.message}')),
            );
          }
          return false;
        }
        _nota = _buscarNotaCreada(estado, idsPrevios, titulo);
      } catch (_) {
        // Sin respuesta a tiempo: se intentará localizar en el próximo guardado
      }
    } else {
      final actualizada = nota.copyWith(title: titulo, content: contenido, tags: tags);
      bloc.add(UpdateNoteEvent(actualizada));
      _nota = actualizada;
      _sucio = false;
      if (cerrar) {
        _cerrar();
        return true;
      }
    }

    if (!mounted) return true;
    setState(() {
      _horaGuardado = DateTime.now();
      _ultimoFueAutomatico = automatico;
    });
    return true;
  }

  Set<String> _idsDeEstado(NotesState estado) {
    if (estado is NotesLoaded) return estado.notes.map((n) => n.id).toSet();
    if (estado is NotesSaving) return estado.notes.map((n) => n.id).toSet();
    return {};
  }

  /// La nota recién creada: una que no existía antes (y con ese título, si
  /// se indica). Si hay varias, la más reciente.
  Note? _buscarNotaCreada(NotesState estado, Set<String> idsPrevios, String? titulo) {
    final notas = estado is NotesLoaded
        ? estado.notes
        : (estado is NotesSaving ? estado.notes : const <Note>[]);
    final candidatas = notas
        .where((n) =>
            !idsPrevios.contains(n.id) &&
            n.courseId == widget.course.id &&
            (titulo == null || n.title == titulo))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return candidatas.isEmpty ? null : candidatas.first;
  }

  void _cerrar() {
    _saliendo = true;
    _temporizadorAutoguardado?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  /// X / Esc: si hay cambios sin guardar pregunta Guardar / Descartar / Cancelar.
  Future<void> _intentarCerrar() async {
    if (!_sucio) {
      _cerrar();
      return;
    }
    final eleccion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text(
          'Este documento tiene cambios que aún no se han guardado.\n'
          '¿Quieres guardarlos antes de cerrar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancelar'),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'descartar'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Descartar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'guardar'),
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (eleccion == 'guardar') {
      await _guardar(cerrar: true);
    } else if (eleccion == 'descartar') {
      _cerrar();
    } else {
      _focoEditor.requestFocus();
    }
  }

  Future<void> _mostrarAyuda() async {
    Widget fila(String atajo, String accion) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 150,
                child: Text(atajo, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              ),
              Expanded(child: Text(accion)),
            ],
          ),
        );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline),
            SizedBox(width: 8),
            Text('Ayuda del editor'),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Usa la barra de herramientas para dar formato, insertar imágenes, '
                  'ecuaciones LaTeX, tablas y oclusiones (texto que se oculta en modo estudio). '
                  'El botón Esquema muestra los títulos de la nota para saltar entre secciones; '
                  'el ancho de la columna se elige en la barra de estado.',
                ),
                const SizedBox(height: 12),
                Text('Atajos', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                fila('Ctrl + S', 'Guardar y seguir editando'),
                fila('F11', 'Modo enfoque (entrar / salir)'),
                fila('Esc', 'Salir del modo enfoque'),
                fila('Ctrl + + / − / 0', 'Tamaño del texto'),
                fila('Ctrl + Z / Ctrl + Y', 'Deshacer / rehacer'),
                const SizedBox(height: 8),
                Text('Formato', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                fila('Ctrl + B / I / U', 'Negrita / cursiva / subrayado'),
                fila('Ctrl + 1 / 2 / 3', 'Título 1 / 2 / 3 (repetir: Normal)'),
                fila('Ctrl + L', 'Lista con viñetas'),
                fila('Ctrl + Shift + L', 'Lista numerada'),
                fila('Ctrl + Shift + C', 'Lista de tareas'),
                fila('Ctrl + Shift + O', 'Marcar / quitar oclusión'),
                fila('Ctrl + K', 'Insertar o editar enlace'),
                fila('Ctrl + `', 'Código en línea'),
                fila('Ctrl + .', 'Superíndice'),
                fila('Ctrl + ,', 'Subíndice'),
                fila('Ctrl + F', 'Buscar en el documento'),
                fila('Ctrl + V', 'Pegar (imágenes, HTML con formato, Markdown…)'),
                fila('Ctrl + Shift + V', 'Pegar como Markdown'),
                const SizedBox(height: 12),
                Text('Guardado', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                const Text(
                  '• El botón Guardar guarda y cierra el editor.\n'
                  '• Se autoguarda cada 30 s si hay cambios y al cambiar de ventana.\n'
                  '• Al cerrar con cambios sin guardar se pide confirmación.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    // Al cerrar el diálogo el foco no vuelve solo al editor y los atajos
    // (F11) no respondían hasta hacer clic: lo devolvemos explícitamente.
    if (mounted) _focoEditor.requestFocus();
  }

  /// Indicador de estado de guardado ("Guardado 12:34" / "Sin guardar").
  Widget _indicadorGuardado(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final estilo = Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12);
    if (_sucio) {
      return Tooltip(
        message: 'Ctrl+S para guardar sin cerrar',
        child: Row(
          key: const Key('indicador-sin-guardar'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: cs.tertiary),
            const SizedBox(width: 6),
            Text('Sin guardar · Ctrl+S', style: estilo?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    final hora = _horaGuardado;
    if (hora == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline, size: 14, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          '${_ultimoFueAutomatico ? 'Autoguardado' : 'Guardado'} ${DateFormat('HH:mm').format(hora)}',
          style: estilo?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEscritorio = !(Platform.isAndroid || Platform.isIOS);
    return PopScope(
      // Esc / atrás con cambios sin guardar: preguntar antes de salir
      canPop: !_sucio || _saliendo,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _intentarCerrar();
      },
      child: Dialog.fullscreen(
        child: AtajosEstudio(
          enfoque: _enfoque,
          onAlternarEnfoque: _alternarEnfoque,
          extra: {
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _guardar(),
          },
          child: Scaffold(
            appBar: _enfoque
                ? null
                : AppBar(
                    title: Text(widget.note == null ? 'Nuevo documento' : 'Editar documento'),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                      onPressed: _intentarCerrar,
                    ),
                    actions: [
                      if (esEscritorio)
                        IconButton(
                          icon: const Icon(Icons.lightbulb_outline, size: 20),
                          tooltip: 'Ayuda y atajos de teclado',
                          onPressed: _mostrarAyuda,
                        ),
                      const BotonesEscalaTexto(),
                      IconButton(
                        icon: const Icon(Icons.fullscreen),
                        tooltip: 'Modo enfoque (F11)',
                        onPressed: _alternarEnfoque,
                      ),
                      Tooltip(
                        message: 'Guardar y cerrar (Ctrl+S guarda sin cerrar)',
                        child: TextButton.icon(
                          onPressed: () => _guardar(cerrar: true),
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar'),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
            body: SafeArea(
              top: _enfoque,
              bottom: false,
              // Modo enfoque: sin AppBar ni cabecera; guardar, tamaño de
              // texto y salir quedan en la barra de estado inferior.
              child: RichDocumentEditor(
                initialContent: _content.isEmpty ? null : _content,
                enfoque: _enfoque,
                focusNode: _focoEditor,
                title: _titleController.text,
                cabecera: _enfoque ? null : _cabecera(context),
                estadoGuardado: _indicadorGuardado(context),
                accionesEstado: _enfoque ? _accionesEnfoque(context) : const [],
                onContentChanged: (content) {
                  _content = content;
                  _marcarSucio();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Cabecera de la hoja: título grande sin borde y etiquetas en línea.
  Widget _cabecera(BuildContext context) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('campo-titulo-documento'),
          controller: _titleController,
          onChanged: (_) => _marcarSucio(),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _focoEditor.requestFocus(),
          style: tema.textTheme.headlineSmall?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            height: 1.25,
          ),
          decoration: InputDecoration.collapsed(
            hintText: 'Título del documento',
            hintStyle: tema.textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        CampoEtiquetas(
          etiquetas: _tags,
          sugerencias: _etiquetasDelCurso(),
          onCambio: () => setState(() => _sucio = true),
        ),
        const SizedBox(height: 4),
        Divider(height: 16, color: cs.outlineVariant.withValues(alpha: 0.5)),
      ],
    );
  }

  /// Etiquetas usadas en otras notas del mismo curso (sugerencias).
  List<String> _etiquetasDelCurso() {
    final estado = context.read<NotesBloc>().state;
    final notas = estado is NotesLoaded
        ? estado.notes
        : (estado is NotesSaving ? estado.notes : const <Note>[]);
    final todas = <String>{
      for (final n in notas)
        if (n.courseId == widget.course.id) ...n.tags,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return todas;
  }

  /// Acciones de la barra de estado en modo enfoque (compactas, 28 px).
  List<Widget> _accionesEnfoque(BuildContext context) {
    Widget mini(String tooltip, Widget icono, VoidCallback? onPressed) => Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onPressed,
            child: SizedBox(width: 30, height: 26, child: Center(child: icono)),
          ),
        );
    final estiloA = Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);
    return [
      const SizedBox(width: 8),
      ValueListenableBuilder<double>(
        valueListenable: EstudioPreferencias.escala,
        builder: (context, escala, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            mini('Texto más pequeño (Ctrl −)', Text('A−', style: estiloA),
                escala > EstudioPreferencias.minimo ? EstudioPreferencias.reducir : null),
            mini('Restablecer tamaño (Ctrl 0)', Text('${(escala * 100).round()}%'),
                EstudioPreferencias.restablecer),
            mini('Texto más grande (Ctrl +)', Text('A+', style: estiloA),
                escala < EstudioPreferencias.maximo ? EstudioPreferencias.aumentar : null),
          ],
        ),
      ),
      mini('Guardar sin cerrar (Ctrl+S)', const Icon(Icons.save_outlined), () => _guardar()),
      mini('Salir del modo enfoque (Esc / F11)', const Icon(Icons.fullscreen_exit), _alternarEnfoque),
    ];
  }
}

/// Etiquetas como chips con un campo en línea "Añadir etiqueta…":
/// Enter (o coma) añade, Backspace con el campo vacío borra la última.
/// Sugiere etiquetas ya usadas en el curso.
class CampoEtiquetas extends StatefulWidget {
  final List<String> etiquetas;
  final List<String> sugerencias;
  final VoidCallback onCambio;

  const CampoEtiquetas({
    super.key,
    required this.etiquetas,
    required this.onCambio,
    this.sugerencias = const [],
  });

  @override
  State<CampoEtiquetas> createState() => _CampoEtiquetasState();
}

class _CampoEtiquetasState extends State<CampoEtiquetas> {
  final _texto = TextEditingController();
  final _foco = FocusNode(debugLabel: 'campo-etiquetas');

  @override
  void dispose() {
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _anadir(String valor) {
    final t = valor.trim().replaceAll(',', '');
    if (t.isNotEmpty && !widget.etiquetas.any((e) => e.toLowerCase() == t.toLowerCase())) {
      widget.etiquetas.add(t);
      widget.onCambio();
    }
    _texto.clear();
    _foco.requestFocus();
  }

  void _quitar(String etiqueta) {
    widget.etiquetas.remove(etiqueta);
    widget.onCambio();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    final estiloChip = tema.textTheme.labelMedium?.copyWith(color: cs.onSecondaryContainer);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.sell_outlined, size: 16, color: cs.onSurfaceVariant),
        for (final e in widget.etiquetas)
          InputChip(
            label: Text(e, style: estiloChip),
            onDeleted: () => _quitar(e),
            deleteIconColor: cs.onSecondaryContainer,
            backgroundColor: cs.secondaryContainer,
            side: BorderSide.none,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.only(left: 8, right: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        SizedBox(
          width: 200,
          child: RawAutocomplete<String>(
            textEditingController: _texto,
            focusNode: _foco,
            optionsBuilder: (valor) {
              final q = valor.text.trim().toLowerCase();
              final usadas = widget.etiquetas.map((e) => e.toLowerCase()).toSet();
              return widget.sugerencias
                  .where((s) => !usadas.contains(s.toLowerCase()) && (q.isEmpty || s.toLowerCase().contains(q)))
                  .take(8);
            },
            onSelected: _anadir,
            fieldViewBuilder: (context, controller, foco, alEnviar) => Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.backspace &&
                    controller.text.isEmpty &&
                    widget.etiquetas.isNotEmpty) {
                  _quitar(widget.etiquetas.last);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                key: const Key('campo-nueva-etiqueta'),
                controller: controller,
                focusNode: foco,
                style: tema.textTheme.bodyMedium,
                onChanged: (v) {
                  if (v.endsWith(',')) _anadir(v);
                },
                onSubmitted: (v) {
                  // Si hay una sugerencia resaltada, RawAutocomplete la elige
                  if (v.trim().isNotEmpty) _anadir(v);
                },
                decoration: InputDecoration.collapsed(
                  hintText: 'Añadir etiqueta…',
                  hintStyle: tema.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                ),
              ),
            ),
            optionsViewBuilder: (context, alElegir, opciones) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(8),
                color: cs.surfaceContainer,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240, maxWidth: 240),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    children: [
                      for (final o in opciones)
                        InkWell(
                          onTap: () => alElegir(o),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(o),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
