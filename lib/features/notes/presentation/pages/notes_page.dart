import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/logger.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../courses/domain/entities/course.dart';
import '../../../pomodoro/presentation/widgets/iniciar_pomodoro.dart';
import '../bloc/notes_bloc.dart';
import '../../domain/entities/note.dart';
import '../widgets/importar_anotador_button.dart';
import '../widgets/note_editor_dialog.dart';
import '../widgets/study_document_viewer.dart';
import 'study_mode_page.dart';
import 'review_page.dart';

/// Orden de la lista de notas del curso.
enum _OrdenNotas { repaso, recientes, titulo }

extension on _OrdenNotas {
  String get etiqueta => switch (this) {
        _OrdenNotas.repaso => 'Pendientes de repaso primero',
        _OrdenNotas.recientes => 'Modificadas recientemente',
        _OrdenNotas.titulo => 'Título (A-Z)',
      };
}

class NotesPage extends StatefulWidget {
  final Course course;

  const NotesPage({super.key, required this.course});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';
  String? _tagSeleccionado;
  _OrdenNotas _orden = _OrdenNotas.repaso;

  /// Análisis del Delta por nota (texto plano, extracto, miniatura).
  /// Clave: id + updatedAt + longitud, para invalidar al editar.
  final Map<String, _AnalisisNota> _cache = {};

  @override
  void initState() {
    super.initState();
    _recargarNotas();
  }

  /// Recarga las notas del curso. Se llama también al volver del modo
  /// estudio/repaso: allí se califican notas y su estado SRS cambia (p. ej.
  /// la etiqueta "Repaso mañana"), pero la lista no se enteraba hasta salir
  /// y volver a entrar al curso.
  void _recargarNotas() {
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<NotesBloc>().add(LoadNotes(authState.user.id, widget.course.id));
    }
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  _AnalisisNota _analisis(Note note) {
    final clave =
        '${note.id}|${note.updatedAt.millisecondsSinceEpoch}|${note.content.length}';
    final previo = _cache[note.id];
    if (previo != null && previo.clave == clave) return previo;
    final nuevo = _AnalisisNota.desde(note, clave);
    _cache[note.id] = nuevo;
    return nuevo;
  }

  /// Aplica búsqueda, filtro por tag y orden.
  List<Note> _filtrar(List<Note> notas) {
    final consulta = _normalizar(_busqueda.trim());
    final filtradas = notas.where((n) {
      if (_tagSeleccionado != null && !n.tags.contains(_tagSeleccionado)) {
        return false;
      }
      if (consulta.isEmpty) return true;
      final a = _analisis(n);
      return consulta
          .split(' ')
          .where((t) => t.isNotEmpty)
          .every((t) => a.textoBusqueda.contains(t));
    }).toList();

    int porFecha(Note a, Note b) => b.updatedAt.compareTo(a.updatedAt);
    switch (_orden) {
      case _OrdenNotas.recientes:
        filtradas.sort(porFecha);
      case _OrdenNotas.titulo:
        filtradas.sort((a, b) =>
            _normalizar(a.title).compareTo(_normalizar(b.title)));
      case _OrdenNotas.repaso:
        final finHoy = _finDelDia(DateTime.now());
        // 0 = vencida, 1 = nueva (sin repasar), 2 = programada a futuro.
        int grupo(DateTime? v) => v == null ? 1 : (v.isAfter(finHoy) ? 2 : 0);
        filtradas.sort((a, b) {
          final va = _venceDe(a);
          final vb = _venceDe(b);
          final g = grupo(va).compareTo(grupo(vb));
          if (g != 0) return g;
          if (va != null && vb != null) {
            final c = va.compareTo(vb);
            if (c != 0) return c;
          }
          return porFecha(a, b);
        });
    }
    return filtradas;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        actions: [
          // Importar capturas del anotador (recarga las notas de este curso)
          ImportarAnotadorButton(courseId: widget.course.id),
          // Botón de revisión SRS
          IconButton(
            icon: const Icon(Icons.psychology),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReviewPage(courseId: widget.course.id),
                ),
              ).then((_) => _recargarNotas());
            },
            tooltip: 'Repasar con SRS',
          ),
          // Pomodoro: pide confirmación si ya hay uno y ofrece "Deshacer".
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: () => iniciarPomodoroConConfirmacion(
              context,
              courseId: widget.course.id,
              nombre: widget.course.name,
            ),
            tooltip: 'Iniciar Pomodoro',
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            onPressed: _abrirModoEstudio,
            tooltip: 'Modo de estudio',
          ),
        ],
      ),
      body: BlocConsumer<NotesBloc, NotesState>(
        listener: (context, state) {
          if (state is NotesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is NotesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<Note>? notasEstado = state is NotesLoaded
              ? state.notes
              : state is NotesSaving
                  ? state.notes
                  : null;

          if (notasEstado != null) {
            if (notasEstado.isEmpty) return _vacio(context);

            final tags = <String>{for (final n in notasEstado) ...n.tags}.toList()
              ..sort((a, b) => _normalizar(a).compareTo(_normalizar(b)));
            if (_tagSeleccionado != null && !tags.contains(_tagSeleccionado)) {
              _tagSeleccionado = null;
            }
            final notas = _filtrar(notasEstado);

            return Column(
              children: [
                _barraFiltros(context, tags, notas.length, notasEstado.length),
                Expanded(
                  child: notas.isEmpty
                      ? _sinResultados(context)
                      : _lista(context, notas),
                ),
              ],
            );
          }

          return const Center(child: Text('Algo salió mal'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo documento'),
      ),
    );
  }

  Widget _vacio(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay notas aún',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primera nota para comenzar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _sinResultados(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Ninguna nota coincide con el filtro',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _busquedaCtrl.clear();
              _busqueda = '';
              _tagSeleccionado = null;
            }),
            child: const Text('Quitar filtros'),
          ),
        ],
      ),
    );
  }

  Widget _barraFiltros(
    BuildContext context,
    List<String> tags,
    int visibles,
    int total,
  ) {
    final esquema = Theme.of(context).colorScheme;
    return Material(
      color: esquema.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _busquedaCtrl,
                        onChanged: (v) => setState(() => _busqueda = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar por título, texto o etiqueta',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          suffixIcon: _busqueda.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Borrar búsqueda',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() {
                                    _busquedaCtrl.clear();
                                    _busqueda = '';
                                  }),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<_OrdenNotas>(
                      tooltip: 'Ordenar: ${_orden.etiqueta}',
                      icon: const Icon(Icons.sort),
                      initialValue: _orden,
                      onSelected: (o) => setState(() => _orden = o),
                      itemBuilder: (_) => [
                        for (final o in _OrdenNotas.values)
                          CheckedPopupMenuItem(
                            value: o,
                            checked: o == _orden,
                            child: Text(o.etiqueta),
                          ),
                      ],
                    ),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: const Text('Todas'),
                            selected: _tagSeleccionado == null,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) =>
                                setState(() => _tagSeleccionado = null),
                          ),
                        ),
                        for (final t in tags)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('#$t'),
                              selected: _tagSeleccionado == t,
                              visualDensity: VisualDensity.compact,
                              onSelected: (sel) => setState(
                                  () => _tagSeleccionado = sel ? t : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (visibles != total)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Mostrando $visibles de $total notas',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: esquema.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lista(BuildContext context, List<Note> notas) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final screenWidth = MediaQuery.of(context).size.width;
    final edgePadding = isMobile ? 10.0 : 16.0;

    _NoteCard tarjeta(Note note, {bool enRejilla = false}) => _NoteCard(
          note: note,
          analisis: _analisis(note),
          enRejilla: enRejilla,
          vence: _venceDe(note),
          onTap: () => _showNoteEditor(note: note),
          onAccion: (accion) => _accion(accion, note),
        );

    // Rejilla en pantallas anchas: columnas de ~420 px (4 en 1920 px),
    // altura fija para mostrar un extracto del contenido, y ancho total
    // limitado para que las tarjetas no se estiren sin fin.
    if (screenWidth > 700) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1760),
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(edgePadding, 6, edgePadding, 88),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 440,
              mainAxisExtent: 196,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: notas.length,
            itemBuilder: (context, index) =>
                tarjeta(notas[index], enRejilla: true),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(edgePadding, 6, edgePadding, 88),
      itemCount: notas.length,
      itemBuilder: (context, index) => tarjeta(notas[index]),
    );
  }

  void _abrirModoEstudio() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<NotesBloc>(),
          child: StudyModePage(
            userId: authState.user.id,
            courseId: widget.course.id,
            courseName: widget.course.name,
          ),
        ),
      ),
    ).then((_) => _recargarNotas());
  }

  void _accion(_AccionNota accion, Note note) {
    switch (accion) {
      case _AccionNota.editar:
        _showNoteEditor(note: note);
      case _AccionNota.estudiar:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _EstudiarNotaPage(note: note)),
        ).then((_) => _recargarNotas());
      case _AccionNota.duplicar:
        _duplicar(note);
      case _AccionNota.eliminar:
        _deleteNote(note);
    }
  }

  void _duplicar(Note note) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    context.read<NotesBloc>().add(CreateNoteEvent(
          courseId: note.courseId,
          userId: authState.user.id,
          title: '${note.title} (copia)',
          content: note.content,
          tags: note.tags,
        ));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Duplicada «${note.title}»')),
      );
  }

  void _showNoteEditor({Note? note}) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<NotesBloc>(),
        child: NoteEditorDialog(
          course: widget.course,
          userId: authState.user.id,
          note: note,
        ),
      ),
    );
  }

  Future<void> _deleteNote(Note note) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Eliminar «${note.title}»?'),
        content: const Text(
          'La nota y su progreso de repaso se borrarán. Las imágenes que '
          'solo use esta nota también se eliminarán del disco.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final bloc = context.read<NotesBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final rutas = _AnalisisNota.rutasImagen(note.content);

    bloc.add(DeleteNoteEvent(note.id, authState.user.id, widget.course.id));

    // Esperar a que el bloc confirme el borrado antes de tocar el disco.
    var borrada = false;
    try {
      final estado = await bloc.stream
          .firstWhere((s) =>
              (s is NotesLoaded && !s.notes.any((n) => n.id == note.id)) ||
              s is NotesError)
          .timeout(const Duration(seconds: 10));
      borrada = estado is NotesLoaded;
    } catch (_) {
      borrada = false;
    }
    if (!borrada) return;

    final eliminadas = await _borrarImagenesHuerfanas(note.id, rutas);
    if (eliminadas > 0) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            'Nota eliminada · $eliminadas imagen${eliminadas == 1 ? '' : 'es'} '
            'sin uso borrada${eliminadas == 1 ? '' : 's'}',
          ),
        ));
    }
  }

  /// Borra de `~/Documentos/sinapsis_images/` y
  /// `~/Documentos/sinapsis/annotated/` las [rutas] que ya no aparezcan en el
  /// contenido de ninguna otra nota (de cualquier curso o usuario).
  Future<int> _borrarImagenesHuerfanas(String noteId, Set<String> rutas) async {
    if (rutas.isEmpty) return 0;
    try {
      final carpetas = await _carpetasImagenes();
      final candidatas = rutas
          .where((r) => carpetas.any((c) => p.isWithin(c, p.normalize(r))))
          .toSet();
      if (candidatas.isEmpty) return 0;

      final raw = sl<SharedPreferences>().getString('NOTES_DATA');
      final otras = <String>[];
      if (raw != null) {
        final todas = json.decode(raw) as Map<String, dynamic>;
        for (final e in todas.entries) {
          if (e.key == noteId) continue;
          final c = (e.value is Map) ? (e.value as Map)['content'] : null;
          if (c is String) otras.add(c);
        }
      }

      var borradas = 0;
      for (final ruta in candidatas) {
        if (otras.any((c) => c.contains(ruta))) continue;
        final f = File(ruta);
        if (await f.exists()) {
          await f.delete();
          borradas++;
          AppLogger.i('Imagen huérfana borrada: $ruta');
        }
      }
      return borradas;
    } catch (e, st) {
      AppLogger.e('No se pudieron limpiar imágenes huérfanas', e, st);
      return 0;
    }
  }

  static Future<List<String>> _carpetasImagenes() async {
    final bases = <String>{};
    final home = Platform.environment['HOME'];
    if (home != null) bases.add(p.join(home, 'Documentos'));
    try {
      bases.add((await getApplicationDocumentsDirectory()).path);
    } catch (_) {}
    return [
      for (final b in bases) ...[
        p.normalize(p.join(b, 'sinapsis_images')),
        p.normalize(p.join(b, 'sinapsis', 'annotated')),
      ],
    ];
  }
}

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

DateTime _finDelDia(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

/// Próximo repaso de la nota, leído de forma tolerante: primero
/// `toJson()['srsDue']` (si el modelo lo expone) y si no `srs.vence`.
/// `null` = nota nueva o sin datos de repaso.
DateTime? _venceDe(Note n) {
  final dynamic d = n;
  try {
    final j = d.toJson();
    if (j is Map) {
      final v = j['srsDue'];
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
    }
  } catch (_) {}
  try {
    final v = d.srs?.vence;
    if (v is DateTime) return v;
  } catch (_) {}
  return null;
}

/// Minúsculas y sin tildes, para buscar sin distinguir acentos.
String _normalizar(String s) {
  const con = 'áàäâéèëêíìïîóòöôúùüûñç';
  const sin = 'aaaaeeeeiiiioooouuuunc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = con.indexOf(ch);
    b.write(i >= 0 ? sin[i] : ch);
  }
  return b.toString();
}

/// Datos derivados del Delta de una nota para la tarjeta.
class _AnalisisNota {
  static const _encabezadoRespuestas = 'Respuestas (no mirar antes de repasar)';
  static const _colorOclusion = '#ffeb3b';

  final String clave;

  /// Título + texto completo + tags, normalizado (para buscar).
  final String textoBusqueda;

  /// Extracto visible: sin oclusiones, sin respuestas y sin el título.
  final String extracto;

  final _Miniatura? miniatura;

  const _AnalisisNota({
    required this.clave,
    required this.textoBusqueda,
    required this.extracto,
    this.miniatura,
  });

  static List<dynamic> _ops(String contenido) {
    try {
      final d = json.decode(contenido);
      if (d is List) return d;
      if (d is Map && d['ops'] is List) return d['ops'] as List;
    } catch (_) {}
    return const [];
  }

  static bool _esOculto(dynamic atributos) {
    if (atributos is! Map) return false;
    if (atributos.containsKey('oclusion')) return true;
    final fondo = atributos['background'];
    return fondo is String && fondo.toLowerCase() == _colorOclusion;
  }

  /// Datos de un embed `image_occluded` (puede venir como JSON en texto).
  static Map<String, dynamic>? _datosOcluida(dynamic v) {
    try {
      if (v is String) return json.decode(v) as Map<String, dynamic>;
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
    return null;
  }

  /// Todas las rutas de imagen (`image` e `image_occluded`) de un Delta.
  static Set<String> rutasImagen(String contenido) {
    final rutas = <String>{};
    for (final op in _ops(contenido)) {
      final insert = op is Map ? op['insert'] : null;
      if (insert is! Map) continue;
      final img = insert['image'];
      if (img is String && img.isNotEmpty) rutas.add(img);
      final datos = _datosOcluida(insert['image_occluded']);
      final ruta = datos?['path'];
      if (ruta is String && ruta.isNotEmpty) rutas.add(ruta);
    }
    return rutas;
  }

  factory _AnalisisNota.desde(Note note, String clave) {
    final completo = StringBuffer();
    final visible = StringBuffer();
    _Miniatura? miniatura;

    for (final op in _ops(note.content)) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is String) {
        completo.write(insert);
        if (_esOculto(op['attributes'])) {
          // Respetar saltos de línea para no pegar palabras.
          visible.write(insert.contains('\n') ? '\n' : ' … ');
        } else {
          visible.write(insert);
        }
      } else if (insert is Map) {
        visible.write('\n');
        if (miniatura == null) {
          final img = insert['image'];
          if (img is String && img.isNotEmpty) {
            miniatura = _Miniatura(ruta: img);
          } else {
            final datos = _datosOcluida(insert['image_occluded']);
            final ruta = datos?['path'];
            if (ruta is String && ruta.isNotEmpty) {
              double leer(Map m, String k) =>
                  ((m[k] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
              final occ = (datos!['occlusions'] as List?) ?? const [];
              miniatura = _Miniatura(
                ruta: ruta,
                aspectRatio: (datos['aspectRatio'] as num?)?.toDouble(),
                oclusiones: [
                  for (final o in occ)
                    if (o is Map)
                      Rect.fromLTRB(leer(o, 'left'), leer(o, 'top'),
                          leer(o, 'right'), leer(o, 'bottom')),
                ],
              );
            }
          }
        }
      }
    }

    // Cortar la sección final de respuestas del anotador.
    var texto = visible.toString();
    final corte = texto.indexOf(_encabezadoRespuestas);
    if (corte >= 0) texto = texto.substring(0, corte);

    // Quitar líneas vacías/separadores y el título repetido al principio.
    final lineas = texto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !RegExp(r'^[─—\-_=]{3,}$').hasMatch(l))
        .toList();
    if (lineas.isNotEmpty &&
        _normalizar(lineas.first) == _normalizar(note.title.trim())) {
      lineas.removeAt(0);
    }
    final extracto = lineas
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return _AnalisisNota(
      clave: clave,
      textoBusqueda: _normalizar(
        '${note.title}\n$completo\n${note.tags.map((t) => '#$t').join(' ')}',
      ).replaceAll(RegExp(r'\s+'), ' '),
      extracto: extracto.length > 400 ? extracto.substring(0, 400) : extracto,
      miniatura: miniatura,
    );
  }
}

class _Miniatura {
  final String ruta;
  final double? aspectRatio;
  final List<Rect> oclusiones;

  const _Miniatura({
    required this.ruta,
    this.aspectRatio,
    this.oclusiones = const [],
  });
}

enum _AccionNota { editar, estudiar, duplicar, eliminar }

// ---------------------------------------------------------------------------
// Tarjeta
// ---------------------------------------------------------------------------

class _NoteCard extends StatelessWidget {
  final Note note;
  final _AnalisisNota analisis;
  final DateTime? vence;
  final VoidCallback onTap;
  final ValueChanged<_AccionNota> onAccion;

  /// En rejilla la tarjeta tiene altura fija: el extracto ocupa el hueco.
  final bool enRejilla;

  const _NoteCard({
    required this.note,
    required this.analisis,
    required this.vence,
    required this.onTap,
    required this.onAccion,
    this.enRejilla = false,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final extracto = analisis.extracto;
    final textoExtracto = Text(
      extracto,
      style: tema.textTheme.bodyMedium?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
      maxLines: enRejilla ? 3 : 2,
      overflow: TextOverflow.ellipsis,
    );

    final cuerpo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                note.title,
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PopupMenuButton<_AccionNota>(
              tooltip: 'Más acciones',
              icon: const Icon(Icons.more_vert, size: 20),
              padding: EdgeInsets.zero,
              onSelected: onAccion,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _AccionNota.editar,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _AccionNota.estudiar,
                  child: ListTile(
                    leading: Icon(Icons.school_outlined),
                    title: Text('Estudiar'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _AccionNota.duplicar,
                  child: ListTile(
                    leading: Icon(Icons.copy_outlined),
                    title: Text('Duplicar'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _AccionNota.eliminar,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Eliminar'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (extracto.isNotEmpty) ...[
          const SizedBox(height: 2),
          if (enRejilla) Expanded(child: textoExtracto) else textoExtracto,
        ] else if (enRejilla)
          const Spacer(),
        if (note.tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: note.tags
                .take(3)
                .map((tag) => Chip(
                      label: Text(tag),
                      labelStyle: const TextStyle(fontSize: 12),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 6),
        _pie(context),
      ],
    );

    return Card(
      margin: enRejilla ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (analisis.miniatura != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: _MiniaturaImagen(miniatura: analisis.miniatura!),
                ),
              ],
              Expanded(child: cuerpo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pie(BuildContext context) {
    final tema = Theme.of(context);
    final gris = tema.textTheme.bodySmall?.copyWith(color: Colors.grey[600]);
    final ahora = DateTime.now();
    final v = vence;
    String? repaso;
    Color? colorRepaso;
    if (v != null) {
      if (!v.isAfter(_finDelDia(ahora))) {
        repaso = 'Repaso pendiente';
        colorRepaso = tema.colorScheme.error;
      } else {
        final dias = DateTime(v.year, v.month, v.day)
            .difference(DateTime(ahora.year, ahora.month, ahora.day))
            .inDays;
        repaso = dias == 1 ? 'Repaso mañana' : 'Repaso en $dias días';
      }
    }
    return Row(
      children: [
        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(_formatDate(note.updatedAt), style: gris),
        if (repaso != null) ...[
          const SizedBox(width: 12),
          Icon(Icons.psychology_outlined,
              size: 15, color: colorRepaso ?? Colors.grey[600]),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              repaso,
              style: gris?.copyWith(
                color: colorRepaso,
                fontWeight: colorRepaso != null ? FontWeight.w600 : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Miniatura de la primera imagen de la nota, con las zonas ocultas
/// dibujadas como rectángulos semitransparentes (no se revela nada).
class _MiniaturaImagen extends StatelessWidget {
  final _Miniatura miniatura;

  const _MiniaturaImagen({required this.miniatura});

  @override
  Widget build(BuildContext context) {
    const ancho = 96.0;
    const alto = 72.0;
    final esquema = Theme.of(context).colorScheme;
    final ar = (miniatura.aspectRatio ?? 0) > 0 ? miniatura.aspectRatio! : null;

    Widget imagen(BoxFit fit) => Image.file(
          File(miniatura.ruta),
          fit: fit,
          cacheWidth: 240,
          errorBuilder: (_, __, ___) => Container(
            color: esquema.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined,
                color: esquema.onSurfaceVariant),
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: ancho,
        height: alto,
        color: esquema.surfaceContainerHighest,
        alignment: Alignment.center,
        child: ar == null
            // Sin proporción conocida no podemos colocar las oclusiones con
            // exactitud: imagen sola recortada.
            ? SizedBox.expand(child: imagen(BoxFit.cover))
            : AspectRatio(
                aspectRatio: ar,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imagen(BoxFit.fill),
                    if (miniatura.oclusiones.isNotEmpty)
                      CustomPaint(
                        painter: _OclusionesPainter(
                          miniatura.oclusiones,
                          esquema.primary,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _OclusionesPainter extends CustomPainter {
  final List<Rect> oclusiones;
  final Color color;

  _OclusionesPainter(this.oclusiones, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final relleno = Paint()..color = color.withValues(alpha: 0.55);
    final borde = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in oclusiones) {
      final rect = Rect.fromLTRB(
        r.left * size.width,
        r.top * size.height,
        r.right * size.width,
        r.bottom * size.height,
      );
      canvas.drawRect(rect, relleno);
      canvas.drawRect(rect, borde);
    }
  }

  @override
  bool shouldRepaint(covariant _OclusionesPainter old) =>
      old.oclusiones != oclusiones || old.color != color;
}

/// Estudio rápido de una sola nota (desde el menú ⋮ → Estudiar).
class _EstudiarNotaPage extends StatefulWidget {
  final Note note;

  const _EstudiarNotaPage({required this.note});

  @override
  State<_EstudiarNotaPage> createState() => _EstudiarNotaPageState();
}

class _EstudiarNotaPageState extends State<_EstudiarNotaPage> {
  bool _mostrarTodo = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note.title),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _mostrarTodo = !_mostrarTodo),
            icon: Icon(_mostrarTodo ? Icons.visibility_off : Icons.visibility),
            label: Text(_mostrarTodo ? 'Ocultar respuestas' : 'Mostrar todo'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: StudyDocumentViewer(
            key: ValueKey(_mostrarTodo),
            content: widget.note.content,
            showOcclusions: _mostrarTodo,
          ),
        ),
      ),
    );
  }
}
