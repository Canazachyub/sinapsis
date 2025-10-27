import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/note.dart';
import '../bloc/notes_bloc.dart';
import '../widgets/study_document_viewer.dart';

/// Pantalla de modo de estudio
/// Muestra las notas con las oclusiones ocultas y permite revelarlas
class StudyModePage extends StatefulWidget {
  final String courseId;
  final String courseName;

  const StudyModePage({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<StudyModePage> createState() => _StudyModePageState();
}

class _StudyModePageState extends State<StudyModePage> {
  int _currentNoteIndex = 0;
  bool _showAnswer = false;
  final List<String> _difficulty = [];

  @override
  void initState() {
    super.initState();
    context.read<NotesBloc>().add(LoadNotes(widget.courseId));
  }

  void _nextNote(List<Note> notes) {
    if (_currentNoteIndex < notes.length - 1) {
      setState(() {
        _currentNoteIndex++;
        _showAnswer = false;
      });
    } else {
      // Sesión completada
      _showCompletionDialog(notes.length);
    }
  }

  void _previousNote() {
    if (_currentNoteIndex > 0) {
      setState(() {
        _currentNoteIndex--;
        _showAnswer = false;
      });
    }
  }

  void _markDifficulty(String level, List<Note> notes) {
    setState(() {
      if (_difficulty.length <= _currentNoteIndex) {
        _difficulty.add(level);
      } else {
        _difficulty[_currentNoteIndex] = level;
      }
    });

    // Avanzar a la siguiente nota
    Future.delayed(const Duration(milliseconds: 500), () {
      _nextNote(notes);
    });
  }

  void _showCompletionDialog(int totalNotes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('¡Sesión Completada!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Has revisado $totalNotes notas.'),
            const SizedBox(height: 16),
            const Text('Estadísticas:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildStat('No sabía', _difficulty.where((d) => d == 'hard').length, Colors.red),
            _buildStat('Difícil', _difficulty.where((d) => d == 'medium').length, Colors.orange),
            _buildStat('Fácil', _difficulty.where((d) => d == 'easy').length, Colors.green),
            _buildStat('Dominada', _difficulty.where((d) => d == 'mastered').length, Colors.blue),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar dialog
              Navigator.pop(context); // Volver a la lista de notas
            },
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text('$label: $count'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: BlocBuilder<NotesBloc, NotesState>(
        builder: (context, state) {
          if (state is NotesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is NotesLoaded) {
            if (state.notes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.note_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No hay notas para estudiar',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              );
            }

            final currentNote = state.notes[_currentNoteIndex];

            return Column(
              children: [
                // Barra de progreso
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Nota ${_currentNoteIndex + 1} de ${state.notes.length}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${((_currentNoteIndex / state.notes.length) * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_currentNoteIndex + 1) / state.notes.length,
                        backgroundColor: Colors.grey[300],
                      ),
                    ],
                  ),
                ),

                // Título de la nota
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    currentNote.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),

                // Documento con oclusiones
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: StudyDocumentViewer(
                      content: currentNote.content,
                      showOcclusions: _showAnswer,
                    ),
                  ),
                ),

                // Botones de acción
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_showAnswer) ...[
                        FilledButton.icon(
                          onPressed: () => setState(() => _showAnswer = true),
                          icon: const Icon(Icons.visibility),
                          label: const Text('Mostrar Respuesta'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          '¿Cómo fue tu desempeño?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDifficultyButton(
                                'No sabía',
                                Colors.red,
                                () => _markDifficulty('hard', state.notes),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDifficultyButton(
                                'Difícil',
                                Colors.orange,
                                () => _markDifficulty('medium', state.notes),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDifficultyButton(
                                'Fácil',
                                Colors.green,
                                () => _markDifficulty('easy', state.notes),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDifficultyButton(
                                'Dominada',
                                Colors.blue,
                                () => _markDifficulty('mastered', state.notes),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: _currentNoteIndex > 0 ? _previousNote : null,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Anterior'),
                          ),
                          TextButton.icon(
                            onPressed: () => _nextNote(state.notes),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Siguiente'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return const Center(child: Text('Error al cargar las notas'));
        },
      ),
    );
  }

  Widget _buildDifficultyButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label),
    );
  }
}
