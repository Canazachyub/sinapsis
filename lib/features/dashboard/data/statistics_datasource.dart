import 'package:drift/drift.dart' hide Column;
import '../../../core/database/database.dart';
import '../../notes/data/datasources/notes_srs_datasource.dart';

/// DataSource para obtener estadísticas de la base de datos
class StatisticsDataSource {
  final AppDatabase _db;
  final NotesSRSDataSource _srsDataSource;

  StatisticsDataSource(this._db, this._srsDataSource);

  /// Obtener total de cursos por usuario
  Future<int> getTotalCoursesByUser(String userId) async {
    final query = _db.select(_db.courses)
      ..where((c) => c.userId.equals(userId));
    final courses = await query.get();
    return courses.length;
  }

  /// Obtener total de notas por usuario
  Future<int> getTotalNotesByUser(String userId) async {
    final query = _db.select(_db.notes)
      ..where((n) => n.userId.equals(userId));
    final notes = await query.get();
    return notes.length;
  }

  /// Obtener total de sesiones de estudio por usuario
  Future<int> getTotalStudySessionsByUser(String userId) async {
    final query = _db.select(_db.studySessions)
      ..where((s) => s.userId.equals(userId));
    final sessions = await query.get();
    return sessions.length;
  }

  /// Obtener tiempo total de estudio en minutos
  Future<int> getTotalStudyTimeMinutes(String userId) async {
    final query = _db.select(_db.studySessions)
      ..where((s) => s.userId.equals(userId));
    final sessions = await query.get();

    int totalSeconds = 0;
    for (final session in sessions) {
      totalSeconds += session.durationSeconds;
    }

    return totalSeconds ~/ 60;
  }

  /// Obtener sesiones de Pomodoro completadas hoy
  Future<int> getTodayPomodorosCount(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final query = _db.select(_db.pomodoroSessions)
      ..where((p) => p.userId.equals(userId));

    final allPomodoros = await query.get();

    // Filtrar en memoria
    final todayPomodoros = allPomodoros.where((p) =>
        p.isCompleted && p.startedAt.isAfter(startOfDay)).toList();

    return todayPomodoros.length;
  }

  /// Obtener tiempo de estudio por día de la semana (últimos 7 días)
  Future<Map<int, int>> getWeeklyStudyTimeMinutes(String userId) async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final query = _db.select(_db.studySessions)
      ..where((s) => s.userId.equals(userId));

    final allSessions = await query.get();

    // Filtrar en memoria
    final weeklySessions = allSessions.where((s) =>
        s.startedAt.isAfter(weekAgo)).toList();

    final Map<int, int> weeklyMinutes = {};
    for (int i = 0; i < 7; i++) {
      weeklyMinutes[i] = 0;
    }

    for (final session in weeklySessions) {
      final dayOfWeek = session.startedAt.weekday - 1; // 0-6 (Lun-Dom)
      weeklyMinutes[dayOfWeek] = (weeklyMinutes[dayOfWeek] ?? 0) + (session.durationSeconds ~/ 60);
    }

    return weeklyMinutes;
  }

  /// Obtener notas que necesitan repaso (usando algoritmo SRS)
  Future<int> getNotesNeedingReviewCount(String userId) async {
    return await _srsDataSource.getNotesNeedingReviewCount(userId);
  }

  /// Obtener estadísticas de retención (notas revisadas vs fallidas)
  Future<Map<String, int>> getRetentionStats(String userId) async {
    final query = _db.select(_db.notes)
      ..where((n) => n.userId.equals(userId));

    final allNotes = await query.get();

    // Filtrar solo notas revisadas al menos una vez
    final notes = allNotes.where((n) => n.reviewCount >= 1).toList();

    int easyCount = 0;
    int mediumCount = 0;
    int hardCount = 0;
    int newCount = 0;

    for (final note in notes) {
      switch (note.difficulty) {
        case 1:
          easyCount++;
          break;
        case 2:
          mediumCount++;
          break;
        case 3:
          hardCount++;
          break;
        default:
          newCount++;
      }
    }

    return {
      'easy': easyCount,
      'medium': mediumCount,
      'hard': hardCount,
      'new': newCount,
    };
  }

  /// Obtener sesiones de Pomodoro de hoy con detalles
  Future<List<PomodoroSession>> getTodayPomodoros(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final query = _db.select(_db.pomodoroSessions)
      ..where((p) => p.userId.equals(userId))
      ..orderBy([(p) => OrderingTerm.desc(p.startedAt)]);

    final allPomodoros = await query.get();

    // Filtrar solo los de hoy
    return allPomodoros.where((p) => p.startedAt.isAfter(startOfDay)).toList();
  }

  /// Obtener tiempo total de Pomodoro hoy en minutos
  Future<int> getTodayPomodoroMinutes(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final query = _db.select(_db.pomodoroSessions)
      ..where((p) => p.userId.equals(userId));

    final allPomodoros = await query.get();

    // Filtrar en memoria para evitar problemas con operadores múltiples
    final todayPomodoros = allPomodoros.where((p) =>
        p.isCompleted &&
        p.startedAt.isAfter(startOfDay)).toList();

    int totalMinutes = 0;
    for (final pomodoro in todayPomodoros) {
      totalMinutes += (pomodoro.workDuration ~/ 60);
    }

    return totalMinutes;
  }
}
