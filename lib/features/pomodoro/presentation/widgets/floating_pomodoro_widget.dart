import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/pomodoro_bloc.dart';
import '../../domain/entities/pomodoro_session.dart';
import 'iniciar_pomodoro.dart';

/// Widget flotante minimalista del Pomodoro que aparece en todas las páginas.
///
/// Por defecto se coloca arriba a la derecha (bajo la barra superior) para no
/// tapar el botón flotante (FAB) ni los SnackBars. Se puede arrastrar; al
/// soltarlo se acopla al borde izquierdo o derecho más cercano y la posición
/// se recuerda entre sesiones. Nunca baja a la franja inferior de la pantalla.
class FloatingPomodoroWidget extends StatefulWidget {
  const FloatingPomodoroWidget({super.key});

  @override
  State<FloatingPomodoroWidget> createState() => _FloatingPomodoroWidgetState();
}

class _FloatingPomodoroWidgetState extends State<FloatingPomodoroWidget> {
  static const _kLado = 'POMODORO_FLOTANTE_LADO';
  static const _kY = 'POMODORO_FLOTANTE_Y';

  /// Margen respecto a los bordes laterales.
  static const double _margen = 12;

  /// Franja inferior reservada para FAB, SnackBars y barra de navegación.
  static const double _zonaInferior = 160;

  /// Bajada de la posición por defecto respecto al borde inferior de la
  /// AppBar, para no tapar las barras de filtros de las páginas.
  static const double _desplazamientoInicial = 120;

  bool _isExpanded = false;

  /// Confirmación en línea de "Detener" (el widget vive fuera del Navigator,
  /// así que no puede abrir diálogos).
  bool _confirmandoStop = false;

  /// Acoplado al borde derecho (true) o izquierdo (false).
  bool _derecha = true;

  /// Distancia desde arriba. `null` = posición por defecto (bajo la AppBar).
  double? _y;

  /// Posición libre mientras se arrastra (esquina superior izquierda).
  Offset? _arrastre;

  @override
  void initState() {
    super.initState();
    _cargarPosicion();
  }

  Future<void> _cargarPosicion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lado = prefs.getString(_kLado);
      final y = prefs.getDouble(_kY);
      if (!mounted) return;
      setState(() {
        if (lado != null) _derecha = lado != 'izquierda';
        _y = y;
      });
    } catch (_) {
      // Sin preferencias: posición por defecto.
    }
  }

  Future<void> _guardarPosicion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLado, _derecha ? 'derecha' : 'izquierda');
      if (_y != null) await prefs.setDouble(_kY, _y!);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenSize = media.size;

    return BlocConsumer<PomodoroBloc, PomodoroBlockState>(
      listenWhen: (a, b) => a.runtimeType != b.runtimeType,
      listener: (context, state) {
        if (_confirmandoStop) setState(() => _confirmandoStop = false);
      },
      builder: (context, state) {
        // Solo mostrar si hay un Pomodoro activo
        if (state is PomodoroInitial) {
          return const SizedBox.shrink();
        }

        final isMobile = Platform.isAndroid || Platform.isIOS;
        final widgetWidth = _isExpanded
            ? (isMobile ? 220.0 : 280.0)
            : (isMobile ? 90.0 : 120.0);
        final widgetHeight = _isExpanded
            ? (_confirmandoStop ? 190.0 : (isMobile ? 120.0 : 140.0))
            : (isMobile ? 64.0 : 80.0);

        // Límites verticales: bajo la AppBar y por encima de la franja
        // inferior (FAB / SnackBar / navegación).
        final minTop = media.padding.top + kToolbarHeight + 8;
        final maxTop = math.max(
          minTop,
          screenSize.height - widgetHeight - _zonaInferior,
        );
        final maxLeft = math.max(0.0, screenSize.width - widgetWidth);

        final double left;
        final double top;
        final arrastre = _arrastre;
        if (arrastre != null) {
          left = arrastre.dx.clamp(0.0, maxLeft);
          top = arrastre.dy.clamp(minTop, maxTop);
        } else {
          left = _derecha
              ? math.max(0.0, screenSize.width - widgetWidth - _margen)
              : _margen;
          // Por defecto, por debajo de la barra de búsqueda/filtros de las
          // páginas (buscador + orden + etiquetas ≈ 110 px): pegado a la
          // AppBar tapaba el botón de ordenar de la página del curso.
          top = (_y ?? minTop + _desplazamientoInicial).clamp(minTop, maxTop);
        }

        return Positioned(
          left: left,
          top: top,
          child: GestureDetector(
            onPanStart: (_) =>
                setState(() => _arrastre = Offset(left, top)),
            onPanUpdate: (details) {
              setState(() {
                _arrastre = (_arrastre ?? Offset(left, top)) + details.delta;
              });
            },
            onPanEnd: (_) {
              final fin = _arrastre ?? Offset(left, top);
              setState(() {
                _derecha = fin.dx + widgetWidth / 2 > screenSize.width / 2;
                _y = fin.dy.clamp(minTop, maxTop);
                _arrastre = null;
              });
              _guardarPosicion();
            },
            child: Material(
              elevation: _arrastre != null ? 12 : 8,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: widgetWidth,
                decoration: BoxDecoration(
                  color: _getBackgroundColor(state),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _arrastre != null
                        ? Colors.white.withValues(alpha: 0.8)
                        : _getBorderColor(state),
                    width: _arrastre != null ? 3 : 2,
                  ),
                  boxShadow: _arrastre != null
                      ? [
                          BoxShadow(
                            color: _getBackgroundColor(state)
                                .withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
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
                              color: Colors.white.withValues(alpha: 0.4),
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

  /// Detener: si quedan más de 1 minuto pide confirmación en línea.
  void _pedirDetener(PomodoroBloc bloc) {
    if (segundosRestantesPomodoro(bloc.state) > 60) {
      setState(() => _confirmandoStop = true);
      return;
    }
    _detener(bloc);
  }

  void _detener(PomodoroBloc bloc) {
    bloc.add(const StopPomodoro());
    setState(() {
      _confirmandoStop = false;
      _isExpanded = false;
    });
  }

  Widget _buildCollapsedView(BuildContext context, PomodoroBlockState state) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
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
        padding: EdgeInsets.fromLTRB(
          isMobile ? 10 : 16, isMobile ? 8 : 12,
          isMobile ? 10 : 16, isMobile ? 10 : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4), // Espacio para la barra de arrastre
            Icon(icon, color: Colors.white, size: isMobile ? 20 : 24),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 13 : 16,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView(BuildContext context, PomodoroBlockState state) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
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
          tooltip: 'Pausar',
          onPressed: () => bloc.add(const PausePomodoro()),
        ),
        _buildActionButton(
          icon: Icons.stop,
          tooltip: 'Detener',
          onPressed: () => _pedirDetener(bloc),
        ),
      ];
    } else if (state is PomodoroPaused) {
      time = state.formattedTime;
      title = 'Pausado';
      actions = [
        _buildActionButton(
          icon: Icons.play_arrow,
          tooltip: 'Reanudar',
          onPressed: () => bloc.add(const ResumePomodoro()),
        ),
        _buildActionButton(
          icon: Icons.stop,
          tooltip: 'Detener',
          onPressed: () => _pedirDetener(bloc),
        ),
      ];
    } else if (state is PomodoroCompleted) {
      title = '¡Completado!';
      time = '00:00';
      actions = [
        _buildActionButton(
          icon: Icons.coffee,
          tooltip: 'Tomar descanso',
          onPressed: () => bloc.add(const SkipToBreak()),
        ),
        _buildActionButton(
          icon: Icons.replay,
          tooltip: 'Otro Pomodoro',
          onPressed: () => bloc.add(const StartPomodoro()),
        ),
      ];
    } else if (state is BreakCompleted) {
      title = '¡Listo!';
      time = '00:00';
      actions = [
        _buildActionButton(
          icon: Icons.play_arrow,
          tooltip: 'Volver al trabajo',
          onPressed: () => bloc.add(const SkipBreak()),
        ),
        _buildActionButton(
          icon: Icons.close,
          tooltip: 'Terminar',
          onPressed: () => _detener(bloc),
        ),
      ];
    }

    return Padding(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
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
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: () => setState(() {
                  _isExpanded = false;
                  _confirmandoStop = false;
                }),
                child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: isMobile ? 18 : 20),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 4 : 8),
          Center(
            child: Text(
              time,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 24 : 32,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          if (_confirmandoStop) ...[
            Text(
              '¿Detener? Quedan '
              '${(segundosRestantesPomodoro(state) / 60).ceil()} min',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => setState(() => _confirmandoStop = false),
                  child: const Text('Continuar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _getBackgroundColor(state),
                  ),
                  onPressed: () => _detener(bloc),
                  child: const Text('Detener'),
                ),
              ],
            ),
          ] else
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
    String? tooltip,
  }) {
    final boton = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
    // app.dart envuelve la app en un Overlay, así que Tooltip funciona aquí.
    return tooltip == null ? boton : Tooltip(message: tooltip, child: boton);
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
    return _getBackgroundColor(state).withValues(alpha: 0.5);
  }
}
