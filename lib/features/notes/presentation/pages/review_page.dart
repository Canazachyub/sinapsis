import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/srs_service.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/datasources/notes_srs_datasource.dart';
import '../../../../core/database/database.dart';
import '../../../pomodoro/presentation/bloc/pomodoro_bloc.dart';

/// Página de revisión SRS para estudiar notas
class ReviewPage extends StatefulWidget {
  final String? courseId;

  const ReviewPage({super.key, this.courseId});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final NotesSRSDataSource _srsDataSource = sl<NotesSRSDataSource>();
  List<Note> _notesToReview = [];
  int _currentIndex = 0;
  bool _showingAnswer = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotesToReview();
  }

  Future<void> _loadNotesToReview() async {
    setState(() => _isLoading = true);

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final notes = widget.courseId != null
          ? await _srsDataSource.getNotesNeedingReviewByCourse(
              authState.user.id,
              widget.courseId!,
            )
          : await _srsDataSource.getNotesNeedingReview(authState.user.id);

      setState(() {
        _notesToReview = notes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando notas: $e')),
        );
      }
    }
  }

  Future<void> _rateNote(int rating) async {
    if (_currentIndex >= _notesToReview.length) return;

    final note = _notesToReview[_currentIndex];

    try {
      await _srsDataSource.reviewNote(note.id, rating);

      setState(() {
        _currentIndex++;
        _showingAnswer = false;
      });

      // Mostrar mensaje de progreso
      if (_currentIndex < _notesToReview.length) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Progreso: ${_currentIndex}/${_notesToReview.length}',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando revisión: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión de Notas'),
        actions: [
          // Botón para iniciar Pomodoro
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: () {
              final authState = context.read<AuthBloc>().state;
              if (authState is Authenticated) {
                context.read<PomodoroBloc>().add(
                      StartPomodoro(
                        courseId: widget.courseId,
                        noteId: _currentIndex < _notesToReview.length
                            ? _notesToReview[_currentIndex].id
                            : null,
                      ),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pomodoro iniciado para esta revisión'),
                  ),
                );
              }
            },
            tooltip: 'Iniciar Pomodoro',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotesToReview,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notesToReview.isEmpty
              ? _buildEmptyState()
              : _currentIndex >= _notesToReview.length
                  ? _buildCompletedState()
                  : _buildReviewCard(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green[400],
          ),
          const SizedBox(height: 24),
          const Text(
            '¡Todo al día!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay notas que necesiten revisión',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.celebration,
            size: 80,
            color: Colors.amber[400],
          ),
          const SizedBox(height: 24),
          const Text(
            '¡Sesión completada!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Has revisado ${_notesToReview.length} ${_notesToReview.length == 1 ? 'nota' : 'notas'}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _loadNotesToReview,
                icon: const Icon(Icons.refresh),
                label: const Text('Revisar más'),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    final note = _notesToReview[_currentIndex];

    return Column(
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _notesToReview.length,
          backgroundColor: Colors.grey[200],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nota ${_currentIndex + 1} de ${_notesToReview.length}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              _buildStateChip(note.srsState),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pregunta:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          note.frontContent,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_showingAnswer) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),
                          const Text(
                            'Respuesta:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            note.backContent ?? 'Sin respuesta',
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Info card
                if (_showingAnswer) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Información SRS',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Intervalo actual',
                              '${note.interval} ${note.interval == 1 ? 'día' : 'días'}'),
                          _buildInfoRow('Factor de facilidad',
                              note.easeFactor.toStringAsFixed(2)),
                          _buildInfoRow('Veces revisada',
                              note.reviewCount.toString()),
                          if (note.lastReviewed != null)
                            _buildInfoRow(
                              'Última revisión',
                              _formatDate(note.lastReviewed!),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: _showingAnswer ? _buildRatingButtons() : _buildShowAnswerButton(),
        ),
      ],
    );
  }

  Widget _buildStateChip(String state) {
    final color = _getStateColor(state);
    final description = SRSService.getStateDescription(state);

    return Chip(
      label: Text(
        description,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide(color: color),
    );
  }

  Color _getStateColor(String state) {
    switch (state) {
      case 'new':
        return Colors.blue;
      case 'learning':
        return Colors.orange;
      case 'review':
        return Colors.green;
      case 'relearning':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Hoy';
    } else if (diff.inDays == 1) {
      return 'Ayer';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildShowAnswerButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => setState(() => _showingAnswer = true),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        child: const Text(
          'Mostrar Respuesta',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildRatingButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '¿Qué tan bien lo recordaste?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildRatingButton(
                'Again',
                'Olvidé',
                Colors.red,
                0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRatingButton(
                'Hard',
                'Difícil',
                Colors.orange,
                1,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRatingButton(
                'Good',
                'Bien',
                Colors.green,
                2,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRatingButton(
                'Easy',
                'Fácil',
                Colors.blue,
                3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingButton(String label, String subtitle, Color color, int rating) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _rateNote(rating),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
