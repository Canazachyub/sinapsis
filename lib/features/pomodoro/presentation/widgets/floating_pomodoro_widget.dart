import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/pomodoro_bloc.dart';
import '../../domain/entities/pomodoro_session.dart';

/// Widget flotante minimalista del Pomodoro que aparece en todas las páginas
/// MOVIBLE: El usuario puede arrastrarlo a cualquier posición
class FloatingPomodoroWidget extends StatefulWidget {
  const FloatingPomodoroWidget({super.key});

  @override
  State<FloatingPomodoroWidget> createState() => _FloatingPomodoroWidgetState();
}

class _FloatingPomodoroWidgetState extends State<FloatingPomodoroWidget> {
  bool _isExpanded = false;

  // Posición del widget (offset desde bottom-right)
  Offset _position = const Offset(16, 80); // right, bottom
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BlocBuilder<PomodoroBloc, PomodoroBlockState>(
      builder: (context, state) {
        // Solo mostrar si hay un Pomodoro activo
        if (state is PomodoroInitial) {
          return const SizedBox.shrink();
        }

        final widgetWidth = _isExpanded ? 280.0 : 120.0;
        final widgetHeight = _isExpanded ? 140.0 : 80.0;

        // Calcular posición real (desde bottom-right)
        final left = screenSize.width - _position.dx - widgetWidth;
        final top = screenSize.height - _position.dy - widgetHeight;

        return Positioned(
          left: left.clamp(0, screenSize.width - widgetWidth),
          top: top.clamp(0, screenSize.height - widgetHeight - 56), // 56 para navbar
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isDragging = true),
            onPanUpdate: (details) {
              setState(() {
                // Actualizar posición basada en el movimiento
                _position = Offset(
                  (_position.dx - details.delta.dx).clamp(8, screenSize.width - widgetWidth - 8),
                  (_position.dy - details.delta.dy).clamp(60, screenSize.height - widgetHeight - 60),
                );
              });
            },
            onPanEnd: (_) => setState(() => _isDragging = false),
            child: Material(
              elevation: _isDragging ? 12 : 8,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: widgetWidth,
                decoration: BoxDecoration(
                  color: _getBackgroundColor(state),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isDragging
                        ? Colors.white.withOpacity(0.8)
                        : _getBorderColor(state),
                    width: _isDragging ? 3 : 2,
                  ),
                  boxShadow: _isDragging ? [
                    BoxShadow(
                      color: _getBackgroundColor(state).withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
                child: Stack(
                  children: [
                    // Indicador de arrastre
                    if (!_isExpanded)
                      Positioned(
                        top: 4,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    // Contenido
                    _isExpanded
                        ? _buildExpandedView(context, state)
                        : _buildCollapsedView(context, state),
                  ],
                ),
              ),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4), // Espacio para la barra de arrastre
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
        _buildActionButton(
          icon: Icons.pause,
          onPressed: () => bloc.add(const PausePomodoro()),
        ),
        _buildActionButton(
          icon: Icons.stop,
          onPressed: () {
            bloc.add(const StopPomodoro());
            setState(() => _isExpanded = false);
          },
        ),
      ];
    } else if (state is PomodoroPaused) {
      time = state.formattedTime;
      title = 'Pausado';
      actions = [
        _buildActionButton(
          icon: Icons.play_arrow,
          onPressed: () => bloc.add(const ResumePomodoro()),
        ),
        _buildActionButton(
          icon: Icons.stop,
          onPressed: () {
            bloc.add(const StopPomodoro());
            setState(() => _isExpanded = false);
          },
        ),
      ];
    } else if (state is PomodoroCompleted) {
      title = '!Completado!';
      time = '00:00';
      actions = [
        _buildActionButton(
          icon: Icons.coffee,
          onPressed: () => bloc.add(const SkipToBreak()),
        ),
        _buildActionButton(
          icon: Icons.replay,
          onPressed: () => bloc.add(const StartPomodoro()),
        ),
      ];
    } else if (state is BreakCompleted) {
      title = '!Listo!';
      time = '00:00';
      actions = [
        _buildActionButton(
          icon: Icons.play_arrow,
          onPressed: () => bloc.add(const SkipBreak()),
        ),
        _buildActionButton(
          icon: Icons.close,
          onPressed: () {
            bloc.add(const StopPomodoro());
            setState(() => _isExpanded = false);
          },
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
              // Barra de arrastre
              Container(
                width: 30,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _isExpanded = false),
                child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
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

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
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
