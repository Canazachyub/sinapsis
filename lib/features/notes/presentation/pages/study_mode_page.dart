import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/estudio_preferencias.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/notes_srs_datasource.dart';
import '../../domain/entities/note.dart';
import '../bloc/notes_bloc.dart';
import '../widgets/estudio_comodo.dart';
import '../widgets/study_document_viewer.dart';
import 'review_page.dart';

/// Modo estudio: recorre todas las notas del curso con las oclusiones
/// tapadas. Las calificaciones se guardan en el repaso espaciado (SM-2),
/// igual que en la página de repaso.
class StudyModePage extends StatefulWidget {
  final String userId;
  final String courseId;
  final String courseName;

  const StudyModePage({
    super.key,
    required this.userId,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<StudyModePage> createState() => _StudyModePageState();
}

class _StudyModePageState extends State<StudyModePage> {
  final NotesSRSDataSource _srs = sl<NotesSRSDataSource>();
  final ScrollController _scroll = ScrollController();

  int _indice = 0;
  bool _mostrando = false;
  bool _guardando = false;

  /// Estado SRS actualizado en esta sesión (las notas del bloc no se recargan).
  final Map<String, EstadoSrs> _srsLocal = {};

  /// Última calificación por nota en esta sesión.
  final Map<String, CalificacionSrs> _calificadas = {};

  /// Modo enfoque: oculta AppBar y barras secundarias (F11 / Esc).
  bool _enfoque = false;

  void _alternarEnfoque() => setState(() => _enfoque = !_enfoque);

  @override
  void initState() {
    super.initState();
    EstudioPreferencias.cargar();
    context.read<NotesBloc>().add(LoadNotes(widget.userId, widget.courseId));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _irA(int indice) {
    setState(() {
      _indice = indice;
      _mostrando = false;
    });
    // Cada nota empieza arriba.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _siguiente(List<Note> notas) {
    if (_indice < notas.length - 1) {
      _irA(_indice + 1);
    } else {
      _dialogoFinal(notas.length);
    }
  }

  void _anterior() {
    if (_indice > 0) _irA(_indice - 1);
  }

  Future<void> _calificar(CalificacionSrs c, List<Note> notas) async {
    if (!_mostrando || _guardando || notas.isEmpty) return;
    final nota = notas[_indice];
    setState(() => _guardando = true);
    try {
      final nuevo = await _srs.calificar(nota.id, c);
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _srsLocal[nota.id] = nuevo;
        _calificadas[nota.id] = c;
      });
      _siguiente(notas);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la calificación: $e')),
      );
    }
  }

  void _dialogoFinal(int total) {
    final cuenta = <CalificacionSrs, int>{};
    for (final c in _calificadas.values) {
      cuenta[c] = (cuenta[c] ?? 0) + 1;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¡Sesión completada!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Has recorrido $total ${total == 1 ? 'nota' : 'notas'} '
                'y calificado ${_calificadas.length}.'),
            const SizedBox(height: 12),
            for (final c in CalificacionSrs.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: colorCalificacion(c), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text('${c.etiqueta}: ${cuenta[c] ?? 0}'),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text('Las calificaciones ya están guardadas en tu repaso espaciado.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _irA(0);
            },
            child: const Text('Empezar de nuevo'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesBloc, NotesState>(
      builder: (context, state) {
        final notas = _notasDe(state) ?? const <Note>[];
        return AtajosEstudio(
          enfoque: _enfoque,
          autofocus: true,
          onAlternarEnfoque: _alternarEnfoque,
          extra: {
            const SingleActivator(LogicalKeyboardKey.arrowRight): () {
              if (notas.isNotEmpty) _siguiente(notas);
            },
            const SingleActivator(LogicalKeyboardKey.arrowLeft): _anterior,
            if (notas.isNotEmpty)
              const SingleActivator(LogicalKeyboardKey.space): () {
                if (!_mostrando) setState(() => _mostrando = true);
              },
            if (notas.isNotEmpty && _mostrando) ...atajosCalificacion((c) => _calificar(c, notas)),
          },
          child: Scaffold(
            // Un solo botón de salir: la flecha "atrás" de la AppBar.
            appBar: _enfoque
                ? null
                : AppBar(
                    title: Text(widget.courseName),
                    actions: [
                      const BotonesEscalaTexto(),
                      IconButton(
                        icon: const Icon(Icons.fullscreen),
                        tooltip: 'Modo enfoque (F11)',
                        onPressed: _alternarEnfoque,
                      ),
                    ],
                  ),
            body: _cuerpo(context, state),
          ),
        );
      },
    );
  }

  static List<Note>? _notasDe(NotesState state) => switch (state) {
        NotesLoaded s => s.notes,
        NotesSaving s => s.notes,
        _ => null,
      };

  Widget _cuerpo(BuildContext context, NotesState state) {
    if (state is NotesLoading || state is NotesInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    final lista = _notasDe(state);
    if (lista == null) {
      return const Center(child: Text('Error al cargar las notas'));
    }
    final cs = Theme.of(context).colorScheme;
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_outlined, size: 80, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No hay notas para estudiar',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    final notas = lista;
    if (_indice >= notas.length) _indice = notas.length - 1;
    final nota = notas[_indice];
    final srs = _srsLocal[nota.id] ?? nota.srs;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final hPadding = isMobile ? 8.0 : 12.0;
    final anchoMaximo = _enfoque ? EstudioLayout.anchoLecturaEnfoque : EstudioLayout.anchoLecturaNormal;

    final columna = Column(
      children: [
        // Indicador único de progreso: "3 de 7" con barra coherente.
        Padding(
          padding: EdgeInsets.fromLTRB(hPadding + 4, _enfoque ? 6 : 8, _enfoque ? 260 : hPadding + 4, 4),
          child: Row(
            children: [
              Text('${_indice + 1} de ${notas.length}',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 12),
              Expanded(
                child: LinearProgressIndicator(
                  value: (_indice + 1) / notas.length,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (_calificadas[nota.id] != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.check_circle, size: 18, color: colorCalificacion(_calificadas[nota.id]!)),
              ],
            ],
          ),
        ),

        // Documento con oclusiones: columna de lectura centrada y escalable
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final lateral = isMobile ? 4.0 : (_enfoque ? 24.0 : 12.0);
              final ancho = (constraints.maxWidth - lateral * 2).clamp(0.0, anchoMaximo).toDouble();
              return SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.symmetric(horizontal: lateral, vertical: _enfoque ? 16 : 4),
                child: Center(
                  child: SizedBox(
                    width: ancho,
                    child: EscalaTextoEstudio(
                      child: AnchoContenidoEstudio(
                        ancho: ancho,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TituloNotaEstudio(note: nota),
                            StudyDocumentViewer(
                              key: ValueKey(nota.id),
                              content: nota.content,
                              showOcclusions: _mostrando,
                              sinMarco: _enfoque,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Container(
          padding: EdgeInsets.fromLTRB(hPadding, 8, hPadding, 8),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: anchoMaximo),
              child: _acciones(notas, srs),
            ),
          ),
        ),
      ],
    );

    if (!_enfoque) return columna;

    return SafeArea(
      child: Stack(
        children: [
          columna,
          Positioned(
            top: 6,
            right: 12,
            child: BarraFlotanteEnfoque(onSalir: _alternarEnfoque),
          ),
        ],
      ),
    );
  }

  Widget _acciones(List<Note> notas, EstadoSrs srs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_mostrando)
          FilledButton.icon(
            onPressed: () => setState(() => _mostrando = true),
            icon: const Icon(Icons.visibility, size: 20),
            label: const Text('Mostrar  (espacio)'),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
          )
        else
          BotonesCalificacion(
            previstos: _srs.previsualizar(srs),
            onCalificar: _guardando ? null : (c) => _calificar(c, notas),
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _indice > 0 ? _anterior : null,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Anterior (←)'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
            TextButton.icon(
              onPressed: () => _siguiente(notas),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Saltar (→)'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
      ],
    );
  }
}
