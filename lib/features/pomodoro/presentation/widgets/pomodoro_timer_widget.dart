import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
import '../bloc/pomodoro_bloc.dart';
import '../../domain/entities/pomodoro_session.dart';

/// Widget del temporizador Pomodoro con diseño circular
class PomodoroTimerWidget extends StatelessWidget {
  const PomodoroTimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PomodoroBloc, PomodoroBlockState>(
      builder: (context, state) {
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context, state),
                const SizedBox(height: 24),
                _buildTimerDisplay(context, state),
                const SizedBox(height: 32),
                _buildControls(context, state),
                const SizedBox(height: 16),
                _buildStats(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, PomodoroBlockState state) {
    String title = 'Pomodoro Timer';
    IconData icon = Icons.timer_outlined;
    Color color = Theme.of(context).colorScheme.primary;

    if (state is PomodoroRunning) {
      if (state.currentState == PomodoroState.working) {
        title = 'Tiempo de Trabajo';
        icon = Icons.work_outline;
        color = Colors.red.shade400;
      } else {
        title = state.isLongBreak ? 'Descanso Largo' : 'Descanso Corto';
        icon = Icons.coffee_outlined;
        color = Colors.green.shade400;
      }
    } else if (state is PomodoroPaused) {
      title = 'Pausado';
      icon = Icons.pause_circle_outline;
      color = Colors.orange.shade400;
    } else if (state is PomodoroCompleted) {
      title = '¡Pomodoro Completado!';
      icon = Icons.celebration;
      color = Colors.green.shade600;
    } else if (state is BreakCompleted) {
      title = '¡Descanso Terminado!';
      icon = Icons.alarm;
      color = Colors.blue.shade600;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerDisplay(BuildContext context, PomodoroBlockState state) {
    String timeText = '25:00';
    double progress = 0.0;
    Color progressColor = Theme.of(context).colorScheme.primary;

    if (state is PomodoroRunning) {
      timeText = state.formattedTime;
      progress = state.progress / 100;
      progressColor = state.currentState == PomodoroState.working
          ? Colors.red.shade400
          : Colors.green.shade400;
    } else if (state is PomodoroPaused) {
      timeText = state.formattedTime;
      progress = 0.5; // Estático en pausado
      progressColor = Colors.orange.shade400;
    }

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Círculo de progreso
          CustomPaint(
            size: const Size(220, 220),
            painter: _CircularProgressPainter(
              progress: progress,
              color: progressColor,
              backgroundColor: progressColor.withOpacity(0.1),
            ),
          ),
          // Tiempo en el centro
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                timeText,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 48,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              if (state is PomodoroRunning) ...[
                const SizedBox(height: 8),
                Text(
                  state.currentState == PomodoroState.working
                      ? 'Enfócate'
                      : 'Relájate',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, PomodoroBlockState state) {
    final bloc = context.read<PomodoroBloc>();

    if (state is PomodoroInitial) {
      return ElevatedButton.icon(
        onPressed: () => bloc.add(const StartPomodoro()),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar Pomodoro'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          backgroundColor: Colors.red.shade400,
          foregroundColor: Colors.white,
        ),
      );
    }

    if (state is PomodoroRunning) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filled(
            onPressed: () => bloc.add(const PausePomodoro()),
            icon: const Icon(Icons.pause),
            tooltip: 'Pausar',
            style: IconButton.styleFrom(
              backgroundColor: Colors.orange.shade400,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          IconButton.filled(
            onPressed: () => bloc.add(const StopPomodoro()),
            icon: const Icon(Icons.stop),
            tooltip: 'Detener',
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade400,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          if (state.currentState == PomodoroState.working)
            IconButton.filled(
              onPressed: () => bloc.add(const SkipToBreak()),
              icon: const Icon(Icons.skip_next),
              tooltip: 'Saltar al descanso',
              style: IconButton.styleFrom(
                backgroundColor: Colors.green.shade400,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      );
    }

    if (state is PomodoroPaused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () => bloc.add(const ResumePomodoro()),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Reanudar'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: Colors.green.shade400,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => bloc.add(const StopPomodoro()),
            icon: const Icon(Icons.stop),
            label: const Text('Cancelar'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: Colors.grey.shade400,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    if (state is PomodoroCompleted) {
      return Column(
        children: [
          Text(
            '¡Excelente trabajo! 🎉',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => bloc.add(const SkipToBreak()),
                icon: const Icon(Icons.coffee),
                label: const Text('Tomar descanso'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.green.shade400,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => bloc.add(const StartPomodoro()),
                icon: const Icon(Icons.replay),
                label: const Text('Otro Pomodoro'),
              ),
            ],
          ),
        ],
      );
    }

    if (state is BreakCompleted) {
      return Column(
        children: [
          Text(
            '¡Listo para continuar!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => bloc.add(const SkipBreak()),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar trabajo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => bloc.add(const StopPomodoro()),
                icon: const Icon(Icons.stop),
                label: const Text('Terminar'),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStats(BuildContext context, PomodoroBlockState state) {
    int completedPomodoros = 0;

    if (state is PomodoroRunning) {
      completedPomodoros = state.completedPomodoros;
    } else if (state is PomodoroPaused) {
      completedPomodoros = state.completedPomodoros;
    } else if (state is PomodoroCompleted) {
      completedPomodoros = state.completedPomodoros;
    } else if (state is BreakCompleted) {
      completedPomodoros = state.completedPomodoros;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 20),
          const SizedBox(width: 8),
          Text(
            '$completedPomodoros ${completedPomodoros == 1 ? 'Pomodoro' : 'Pomodoros'} completados hoy',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

/// Painter para el círculo de progreso
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Círculo de fondo
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0;

    canvas.drawCircle(center, radius - 6, backgroundPaint);

    // Círculo de progreso
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -math.pi / 2, // Comenzar desde arriba
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
