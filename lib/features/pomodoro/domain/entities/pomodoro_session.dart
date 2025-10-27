import 'package:equatable/equatable.dart';

/// Estados del Pomodoro
enum PomodoroState {
  idle, // Sin comenzar
  working, // En periodo de trabajo
  breakTime, // En descanso
  paused, // Pausado
  completed, // Completado
}

/// Sesión de Pomodoro
class PomodoroSession extends Equatable {
  final String id;
  final String userId;
  final String? courseId;
  final String? noteId;
  final int workDuration; // Duración del trabajo en segundos (default 1500 = 25 min)
  final int breakDuration; // Duración del descanso en segundos (default 300 = 5 min)
  final bool isCompleted;
  final bool wasInterrupted;
  final DateTime startedAt;
  final DateTime? completedAt;

  const PomodoroSession({
    required this.id,
    required this.userId,
    this.courseId,
    this.noteId,
    this.workDuration = 1500,
    this.breakDuration = 300,
    this.isCompleted = false,
    this.wasInterrupted = false,
    required this.startedAt,
    this.completedAt,
  });

  /// Duración total de la sesión en segundos
  int get totalDuration {
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt).inSeconds;
  }

  /// Duración en minutos
  int get durationMinutes => totalDuration ~/ 60;

  /// Porcentaje de completitud (0-100)
  double get completionPercentage {
    if (isCompleted) return 100.0;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    return (elapsed / workDuration * 100).clamp(0, 100);
  }

  PomodoroSession copyWith({
    String? id,
    String? userId,
    String? courseId,
    String? noteId,
    int? workDuration,
    int? breakDuration,
    bool? isCompleted,
    bool? wasInterrupted,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return PomodoroSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      noteId: noteId ?? this.noteId,
      workDuration: workDuration ?? this.workDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      isCompleted: isCompleted ?? this.isCompleted,
      wasInterrupted: wasInterrupted ?? this.wasInterrupted,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        courseId,
        noteId,
        workDuration,
        breakDuration,
        isCompleted,
        wasInterrupted,
        startedAt,
        completedAt,
      ];
}

/// Configuración personalizada del Pomodoro
class PomodoroConfig extends Equatable {
  final int workMinutes;
  final int breakMinutes;
  final int longBreakMinutes;
  final int sessionsUntilLongBreak;
  final bool autoStartBreaks;
  final bool autoStartPomodoros;

  const PomodoroConfig({
    this.workMinutes = 25,
    this.breakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsUntilLongBreak = 4,
    this.autoStartBreaks = false,
    this.autoStartPomodoros = false,
  });

  int get workSeconds => workMinutes * 60;
  int get breakSeconds => breakMinutes * 60;
  int get longBreakSeconds => longBreakMinutes * 60;

  PomodoroConfig copyWith({
    int? workMinutes,
    int? breakMinutes,
    int? longBreakMinutes,
    int? sessionsUntilLongBreak,
    bool? autoStartBreaks,
    bool? autoStartPomodoros,
  }) {
    return PomodoroConfig(
      workMinutes: workMinutes ?? this.workMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      sessionsUntilLongBreak: sessionsUntilLongBreak ?? this.sessionsUntilLongBreak,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      autoStartPomodoros: autoStartPomodoros ?? this.autoStartPomodoros,
    );
  }

  @override
  List<Object?> get props => [
        workMinutes,
        breakMinutes,
        longBreakMinutes,
        sessionsUntilLongBreak,
        autoStartBreaks,
        autoStartPomodoros,
      ];
}
