part of 'pomodoro_bloc.dart';

/// Eventos del Pomodoro
abstract class PomodoroEvent extends Equatable {
  const PomodoroEvent();

  @override
  List<Object?> get props => [];
}

/// Iniciar un nuevo Pomodoro
class StartPomodoro extends PomodoroEvent {
  final String? courseId;
  final String? noteId;

  const StartPomodoro({this.courseId, this.noteId});

  @override
  List<Object?> get props => [courseId, noteId];
}

/// Pausar el Pomodoro actual
class PausePomodoro extends PomodoroEvent {
  const PausePomodoro();
}

/// Reanudar el Pomodoro pausado
class ResumePomodoro extends PomodoroEvent {
  const ResumePomodoro();
}

/// Detener/cancelar el Pomodoro
class StopPomodoro extends PomodoroEvent {
  const StopPomodoro();
}

/// Saltar al descanso
class SkipToBreak extends PomodoroEvent {
  const SkipToBreak();
}

/// Saltar el descanso
class SkipBreak extends PomodoroEvent {
  final String? courseId;
  final String? noteId;

  const SkipBreak({this.courseId, this.noteId});

  @override
  List<Object?> get props => [courseId, noteId];
}

/// Actualizar configuración (solo cuando está inactivo)
class UpdateConfig extends PomodoroEvent {
  final PomodoroConfig config;

  const UpdateConfig(this.config);

  @override
  List<Object?> get props => [config];
}

/// Resetear contador de pomodoros completados
class ResetPomodoro extends PomodoroEvent {
  const ResetPomodoro();
}

/// Establecer el ID del usuario actual
class SetUserId extends PomodoroEvent {
  final String userId;

  const SetUserId(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Evento interno para el tick del timer
class _TickPomodoro extends PomodoroEvent {
  const _TickPomodoro();
}
