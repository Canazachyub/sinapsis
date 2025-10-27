part of 'pomodoro_bloc.dart';

/// Estados del Pomodoro Bloc
abstract class PomodoroBlockState extends Equatable {
  const PomodoroBlockState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial - sin sesión activa
class PomodoroInitial extends PomodoroBlockState {
  const PomodoroInitial();
}

/// Pomodoro en ejecución
class PomodoroRunning extends PomodoroBlockState {
  final PomodoroState currentState;
  final int remainingSeconds;
  final int totalSeconds;
  final int completedPomodoros;
  final String? courseId;
  final String? noteId;
  final DateTime startedAt;
  final bool isLongBreak;

  const PomodoroRunning({
    required this.currentState,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.completedPomodoros,
    this.courseId,
    this.noteId,
    required this.startedAt,
    this.isLongBreak = false,
  });

  /// Porcentaje de progreso (0-100)
  double get progress {
    if (totalSeconds == 0) return 0;
    return ((totalSeconds - remainingSeconds) / totalSeconds * 100).clamp(0, 100);
  }

  /// Tiempo restante en formato MM:SS
  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
        currentState,
        remainingSeconds,
        totalSeconds,
        completedPomodoros,
        courseId,
        noteId,
        startedAt,
        isLongBreak,
      ];
}

/// Pomodoro pausado
class PomodoroPaused extends PomodoroBlockState {
  final PomodoroState previousState;
  final int remainingSeconds;
  final int totalSeconds;
  final int completedPomodoros;
  final String? courseId;
  final String? noteId;
  final DateTime startedAt;

  const PomodoroPaused({
    required this.previousState,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.completedPomodoros,
    this.courseId,
    this.noteId,
    required this.startedAt,
  });

  /// Tiempo restante en formato MM:SS
  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
        previousState,
        remainingSeconds,
        totalSeconds,
        completedPomodoros,
        courseId,
        noteId,
        startedAt,
      ];
}

/// Pomodoro completado (trabajo terminado)
class PomodoroCompleted extends PomodoroBlockState {
  final int completedPomodoros;
  final String? courseId;
  final String? noteId;

  const PomodoroCompleted({
    required this.completedPomodoros,
    this.courseId,
    this.noteId,
  });

  @override
  List<Object?> get props => [completedPomodoros, courseId, noteId];
}

/// Descanso completado
class BreakCompleted extends PomodoroBlockState {
  final int completedPomodoros;

  const BreakCompleted({
    required this.completedPomodoros,
  });

  @override
  List<Object?> get props => [completedPomodoros];
}
