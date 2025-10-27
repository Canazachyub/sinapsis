import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../notes/data/datasources/notes_srs_datasource.dart';
import '../../../../core/services/srs_service.dart';

/// Página de estadísticas del sistema SRS
class SRSStatsPage extends StatefulWidget {
  const SRSStatsPage({super.key});

  @override
  State<SRSStatsPage> createState() => _SRSStatsPageState();
}

class _SRSStatsPageState extends State<SRSStatsPage> {
  final NotesSRSDataSource _srsDataSource = sl<NotesSRSDataSource>();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final stats = await _srsDataSource.getSRSStats(authState.user.id);
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando estadísticas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas SRS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? const Center(child: Text('No hay datos disponibles'))
              : _buildStatsContent(),
    );
  }

  Widget _buildStatsContent() {
    final stats = _stats!;
    final totalNotes = stats['totalNotes'] as int;
    final newNotes = stats['newNotes'] as int;
    final learningNotes = stats['learningNotes'] as int;
    final reviewNotes = stats['reviewNotes'] as int;
    final relearnNotes = stats['relearnNotes'] as int;
    final totalReviews = stats['totalReviews'] as int;
    final avgEaseFactor = stats['avgEaseFactor'] as double;
    final avgRetention = stats['avgRetention'] as double;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Resumen general
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Resumen General',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStatRow('Total de Notas', totalNotes.toString()),
                _buildStatRow('Total de Revisiones', totalReviews.toString()),
                _buildStatRow(
                  'Retención Promedio',
                  '${(avgRetention * 100).toStringAsFixed(1)}%',
                ),
                _buildStatRow(
                  'Factor de Facilidad',
                  avgEaseFactor.toStringAsFixed(2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Distribución por estado
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distribución por Estado',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (totalNotes > 0) ...[
                  _buildProgressBar(
                    'Nuevas',
                    newNotes,
                    totalNotes,
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildProgressBar(
                    'Aprendiendo',
                    learningNotes,
                    totalNotes,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildProgressBar(
                    'En Repaso',
                    reviewNotes,
                    totalNotes,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildProgressBar(
                    'Reaprendiendo',
                    relearnNotes,
                    totalNotes,
                    Colors.red,
                  ),
                ] else
                  const Text('No hay notas para mostrar'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Métricas de rendimiento
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Métricas de Rendimiento',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Tasa de Éxito',
                        _calculateSuccessRate(stats),
                        Icons.trending_up,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Notas Dominadas',
                        reviewNotes.toString(),
                        Icons.check_circle,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Información sobre el algoritmo
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sobre el Algoritmo SRS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'El sistema utiliza el algoritmo SM-2 (SuperMemo 2), el mismo que usa Anki. '
                  'Este algoritmo ajusta automáticamente los intervalos de repaso basándose en tu desempeño, '
                  'optimizando tu retención a largo plazo.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Again: Vuelve a fase de aprendizaje\n'
                  '• Hard: Intervalo x1.2\n'
                  '• Good: Intervalo x Factor de Facilidad\n'
                  '• Easy: Intervalo x Factor x 1.3',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, int value, int total, Color color) {
    final percentage = total > 0 ? value / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '$value (${(percentage * 100).toStringAsFixed(0)}%)',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _calculateSuccessRate(Map<String, dynamic> stats) {
    final reviewNotes = stats['reviewNotes'] as int;
    final totalNotes = stats['totalNotes'] as int;

    if (totalNotes == 0) return '0%';

    final successRate = (reviewNotes / totalNotes) * 100;
    return '${successRate.toStringAsFixed(0)}%';
  }
}
