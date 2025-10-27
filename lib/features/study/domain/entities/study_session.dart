import 'package:equatable/equatable.dart';

/// Dificultad de la respuesta según el usuario
enum Difficulty {
  again, // No recordó
  hard, // Difícil
  good, // Bien
  easy, // Fácil
}

/// Registro de respuesta individual en una sesión
class StudyRecord extends Equatable {
  final String noteId;
  final Difficulty difficulty;
  final DateTime timestamp;

  const StudyRecord({
    required this.noteId,
    required this.difficulty,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [noteId, difficulty, timestamp];
}

/// Sesión de estudio
class StudySession extends Equatable {
  final String id;
  final String userId;
  final String courseId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<StudyRecord> records;
  final int totalCards;
  final int reviewedCards;

  const StudySession({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.startTime,
    this.endTime,
    this.records = const [],
    required this.totalCards,
    this.reviewedCards = 0,
  });

  /// Duración de la sesión en segundos
  int get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inSeconds;
  }

  /// Porcentaje de progreso
  double get progress {
    if (totalCards == 0) return 0;
    return (reviewedCards / totalCards) * 100;
  }

  /// Tasa de aciertos (% de cards marcadas como good o easy)
  double get successRate {
    if (records.isEmpty) return 0;
    final successful = records.where((r) =>
        r.difficulty == Difficulty.good || r.difficulty == Difficulty.easy).length;
    return (successful / records.length) * 100;
  }

  StudySession copyWith({
    String? id,
    String? userId,
    String? courseId,
    DateTime? startTime,
    DateTime? endTime,
    List<StudyRecord>? records,
    int? totalCards,
    int? reviewedCards,
  }) {
    return StudySession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      records: records ?? this.records,
      totalCards: totalCards ?? this.totalCards,
      reviewedCards: reviewedCards ?? this.reviewedCards,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        courseId,
        startTime,
        endTime,
        records,
        totalCards,
        reviewedCards,
      ];
}
