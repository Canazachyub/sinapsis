import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/pomodoro_bloc.dart';

/// Inicia un Pomodoro desde una pantalla de estudio (curso o nota) sin
/// sorpresas:
///   * si ya hay uno en marcha o en pausa, pide confirmación antes de
///     reiniciarlo (se perdería el tiempo transcurrido);
///   * si no había ninguno, lo inicia y muestra un SnackBar con "Deshacer".
///
/// [nombre] es lo que se está estudiando (p. ej. el curso) para el mensaje.
Future<void> iniciarPomodoroConConfirmacion(
  BuildContext context, {
  String? courseId,
  String? noteId,
  String? nombre,
}) async {
  final bloc = context.read<PomodoroBloc>();
  final estado = bloc.state;
  final enCurso = estado is PomodoroRunning || estado is PomodoroPaused;

  if (enCurso) {
    final restante = estado is PomodoroRunning
        ? estado.formattedTime
        : (estado as PomodoroPaused).formattedTime;
    final reiniciar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reiniciar el Pomodoro?'),
        content: Text(
          'Ya hay un Pomodoro en curso (quedan $restante). '
          'Si empiezas otro se perderá el tiempo transcurrido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir con el actual'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empezar de nuevo'),
          ),
        ],
      ),
    );
    if (reiniciar != true) return;
  }

  bloc.add(StartPomodoro(courseId: courseId, noteId: noteId));

  if (!context.mounted) return;
  final texto = nombre == null || nombre.isEmpty
      ? 'Pomodoro iniciado'
      : 'Pomodoro iniciado para $nombre';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        duration: const Duration(seconds: 5),
        // Desde Flutter 3.29 un SnackBar con acción tiene `persist: true` por
        // defecto y NO se cierra al vencer `duration` (se quedaba para
        // siempre). Lo forzamos a desaparecer a los 5 s.
        persist: false,
        // Solo ofrecemos deshacer si antes no había ninguno: detenerlo
        // devuelve exactamente al estado anterior.
        action: enCurso
            ? null
            : SnackBarAction(
                label: 'Deshacer',
                onPressed: () => bloc.add(const StopPomodoro()),
              ),
      ),
    );
}

/// Detiene el Pomodoro pidiendo confirmación si quedan más de 1 minuto
/// (para no perder una sesión por un clic accidental).
Future<void> detenerPomodoroConConfirmacion(BuildContext context) async {
  final bloc = context.read<PomodoroBloc>();
  final restante = segundosRestantesPomodoro(bloc.state);
  if (restante > 60) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Detener el Pomodoro?'),
        content: Text(
          'Quedan ${(restante / 60).ceil()} min. La sesión actual no se '
          'contará como completada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Detener'),
          ),
        ],
      ),
    );
    if (ok != true) return;
  }
  bloc.add(const StopPomodoro());
}

/// Segundos que quedan de la sesión actual (0 si no hay ninguna en curso).
int segundosRestantesPomodoro(PomodoroBlockState estado) {
  if (estado is PomodoroRunning) return estado.remainingSeconds;
  if (estado is PomodoroPaused) return estado.remainingSeconds;
  return 0;
}
