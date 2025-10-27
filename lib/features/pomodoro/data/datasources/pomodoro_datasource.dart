import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../../../core/database/database.dart';

/// DataSource para operaciones de Pomodoro usando Drift
class PomodoroDataSource {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  PomodoroDataSource(this._db);

  /// Guarda una sesión de Pomodoro completada en la base de datos
  Future<String> savePomodoroSession({
    required String userId,
    String? courseId,
    String? noteId,
    required int workDuration,
    required int breakDuration,
    required DateTime startedAt,
    bool wasInterrupted = false,
  }) async {
    final sessionId = _uuid.v4();

    await _db.into(_db.pomodoroSessions).insert(
      PomodoroSessionsCompanion.insert(
        id: sessionId,
        userId: userId,
        courseId: drift.Value(courseId),
        noteId: drift.Value(noteId),
        workDuration: drift.Value(workDuration),
        breakDuration: drift.Value(breakDuration),
        isCompleted: const drift.Value(true),
        wasInterrupted: drift.Value(wasInterrupted),
        startedAt: startedAt,
        completedAt: drift.Value(DateTime.now()),
      ),
    );

    // Si está asociado a un curso, crear también una sesión de estudio
    if (courseId != null) {
      await _createStudySession(
        userId: userId,
        courseId: courseId,
        noteId: noteId,
        durationSeconds: workDuration,
        startedAt: startedAt,
      );
    }

    return sessionId;
  }

  /// Crea una sesión de estudio asociada al Pomodoro
  Future<void> _createStudySession({
    required String userId,
    required String courseId,
    String? noteId,
    required int durationSeconds,
    required DateTime startedAt,
  }) async {
    final sessionId = _uuid.v4();

    await _db.into(_db.studySessions).insert(
      StudySessionsCompanion.insert(
        id: sessionId,
        userId: userId,
        courseId: courseId,
        cardsReviewed: 0, // Pomodoro no tiene tarjetas revisadas
        cardsCorrect: 0,
        durationSeconds: durationSeconds,
        startedAt: startedAt,
        endedAt: drift.Value(DateTime.now()),
        sessionType: const drift.Value('pomodoro'),
        noteId: drift.Value(noteId),
      ),
    );
  }

  /// Obtiene todas las sesiones de Pomodoro de un usuario
  Future<List<PomodoroSession>> getPomodoroSessionsByUser(String userId) async {
    final query = _db.select(_db.pomodoroSessions)
      ..where((p) => p.userId.equals(userId))
      ..orderBy([(p) => drift.OrderingTerm.desc(p.startedAt)]);

    return await query.get();
  }

  /// Obtiene sesiones de Pomodoro por curso
  Future<List<PomodoroSession>> getPomodoroSessionsByCourse(
    String userId,
    String courseId,
  ) async {
    final query = _db.select(_db.pomodoroSessions)
      ..where((p) => p.userId.equals(userId))
      ..orderBy([(p) => drift.OrderingTerm.desc(p.startedAt)]);

    final allSessions = await query.get();
    return allSessions.where((s) => s.courseId == courseId).toList();
  }

  /// Obtiene sesiones de Pomodoro por nota
  Future<List<PomodoroSession>> getPomodoroSessionsByNote(
    String userId,
    String noteId,
  ) async {
    final query = _db.select(_db.pomodoroSessions)
      ..where((p) => p.userId.equals(userId))
      ..orderBy([(p) => drift.OrderingTerm.desc(p.startedAt)]);

    final allSessions = await query.get();
    return allSessions.where((s) => s.noteId == noteId).toList();
  }

  /// Obtiene el total de minutos de Pomodoro por usuario
  Future<int> getTotalPomodoroMinutes(String userId) async {
    final query = _db.select(_db.pomodoroSessions)
      ..where((p) => p.userId.equals(userId) & p.isCompleted.equals(true));

    final sessions = await query.get();

    int totalSeconds = 0;
    for (final session in sessions) {
      totalSeconds += session.workDuration;
    }

    return totalSeconds ~/ 60;
  }

  /// Obtiene estadísticas de Pomodoro de hoy
  Future<Map<String, dynamic>> getTodayPomodoroStats(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final query = _db.select(_db.pomodoroSessions)
      ..where((p) => p.userId.equals(userId));

    final allSessions = await query.get();

    final todaySessions = allSessions.where((s) =>
        s.isCompleted && s.startedAt.isAfter(startOfDay)).toList();

    int totalMinutes = 0;
    for (final session in todaySessions) {
      totalMinutes += session.workDuration ~/ 60;
    }

    return {
      'count': todaySessions.length,
      'totalMinutes': totalMinutes,
      'completed': todaySessions.where((s) => !s.wasInterrupted).length,
      'interrupted': todaySessions.where((s) => s.wasInterrupted).length,
    };
  }

  /// Obtiene la racha actual de días con al menos un Pomodoro
  Future<int> getCurrentStreak(String userId) async {
    final query = _db.select(_db.pomodoroSessions)
      ..where((p) => p.userId.equals(userId) & p.isCompleted.equals(true))
      ..orderBy([(p) => drift.OrderingTerm.desc(p.startedAt)]);

    final sessions = await query.get();

    if (sessions.isEmpty) return 0;

    int streak = 0;
    DateTime? lastDate;

    for (final session in sessions) {
      final sessionDate = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );

      if (lastDate == null) {
        // Primera sesión
        lastDate = sessionDate;
        streak = 1;
      } else {
        final daysDiff = lastDate.difference(sessionDate).inDays;

        if (daysDiff == 0) {
          // Mismo día, continuar
          continue;
        } else if (daysDiff == 1) {
          // Día consecutivo
          streak++;
          lastDate = sessionDate;
        } else {
          // Se rompió la racha
          break;
        }
      }
    }

    return streak;
  }
}
