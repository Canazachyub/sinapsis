import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/pomodoro_bloc.dart';
import '../../domain/entities/pomodoro_session.dart';

/// Widget flotante minimalista del Pomodoro que aparece en todas las páginas
class FloatingPomodoroWidget extends StatefulWidget {
  const FloatingPomodoroWidget({super.key});

  @override
  State<FloatingPomodoroWidget> createState() => _FloatingPomodoroWidgetState();
}

class _FloatingPomodoroWidgetState extends State<FloatingPomodoroWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PomodoroBloc, PomodoroBlockState>(
      builder: (context, state) {
        // Solo mostrar si hay un Pomodoro activo
        if (state is PomodoroInitial) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 80,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isExpanded ? 280 : 120,
              decoration: BoxDecoration(
                color: _getBackgroundColor(state),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getBorderColor(state),
                  width: 2,
                ),
              ),
              child: _isExpanded
                  ? _buildExpandedView(context, state)
                  : _buildCollapsedView(context, state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedView(BuildContext context, PomodoroBlockState state) {
    String time = '25:00';
    IconData icon = Icons.timer;

    if (state is PomodoroRunning) {
      time = state.formattedTime;
      icon = state.currentState == PomodoroState.working
          ? Icons.work_outline
          : Icons.coffee_outlined;
    } else if (state is PomodoroPaused) {
      time = state.formattedTime;
      icon = Icons.pause;
    }

    return InkWell(
      onTap: () => setState(() => _isExpanded = true),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView(BuildContext context, PomodoroBlockState state) {
    final bloc = context.read<PomodoroBloc>();

    String title = 'Pomodoro';
    String time = '25:00';
    List<Widget> actions = [];

    if (state is PomodoroRunning) {
      time = state.formattedTime;
      title = state.currentState == PomodoroState.working ? 'Trabajando' : 'Descanso';
      actions = [
        IconButton(
          onPressed: () => bloc.add(const PausePomodoro()),
          icon: const Icon(Icons.pause, color: Colors.white),
          tooltip: 'Pausar',
          iconSize: 20,
        ),
        IconButton(
          onPressed: () {
            bloc.add(const StopPomodoro());
            setState(() => _isExpanded = false);
          },
          icon: const Icon(Icons.stop, color: Colors.white),
          tooltip: 'Detener',
          iconSize: 20,
        ),
      ];
    } else if (state is PomodoroPaused) {
      time = state.formattedTime;
      title = 'Pausado';
      actions = [
        IconButton(
          onPressed: () => bloc.add(const ResumePomodoro()),
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          tooltip: 'Reanudar',
          iconSize: 20,
        ),
        IconButton(
          onPressed: () {
            bloc.add(const StopPomodoro());
            setState(() => _isExpanded = false);
          },
          icon: const Icon(Icons.stop, color: Colors.white),
          tooltip: 'Detener',
          iconSize: 20,
        ),
      ];
    } else if (state is PomodoroCompleted) {
      title = '¡Completado!';
      time = '00:00';
      actions = [
        IconButton(
          onPressed: () => bloc.add(const SkipToBreak()),
          icon: const Icon(Icons.coffee, color: Colors.white),
          tooltip: 'Descanso',
          iconSize: 20,
        ),
        IconButton(
          onPressed: () {
            bloc.add(const StartPomodoro());
          },
          icon: const Icon(Icons.replay, color: Colors.white),
          tooltip: 'Otro',
          iconSize: 20,
        ),
      ];
    } else if (state is BreakCompleted) {
      title = '¡Listo!';
      time = '00:00';
      actions = [
        IconButton(
          onPressed: () => bloc.add(const SkipBreak()),
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          tooltip: 'Trabajar',
          iconSize: 20,
        ),
        IconButton(
          onPressed: () {
            bloc.add(const StopPomodoro());
            setState(() => _isExpanded = false);
          },
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'Cerrar',
          iconSize: 20,
        ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _isExpanded = false),
                icon: const Icon(Icons.minimize, color: Colors.white),
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: actions,
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(PomodoroBlockState state) {
    if (state is PomodoroRunning) {
      return state.currentState == PomodoroState.working
          ? Colors.red.shade400
          : Colors.green.shade400;
    } else if (state is PomodoroPaused) {
      return Colors.orange.shade400;
    } else if (state is PomodoroCompleted) {
      return Colors.green.shade600;
    } else if (state is BreakCompleted) {
      return Colors.blue.shade600;
    }
    return Colors.grey.shade400;
  }

  Color _getBorderColor(PomodoroBlockState state) {
    return _getBackgroundColor(state).withOpacity(0.5);
  }
}
