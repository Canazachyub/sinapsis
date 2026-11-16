import 'package:drift/drift.dart' hide Column;
import '../../../core/database/database.dart';
import '../../notes/data/datasources/notes_srs_datasource.dart';

/// Estadísticas del dashboard.
///
/// Cursos, notas y repaso espaciado se leen de SharedPreferences (los datos
/// reales, vía [NotesSRSDataSource]). Drift solo se usa para sesiones de
/// estudio y pomodoro.
class StatisticsDataSource {
  final AppDatabase _db;
  final NotesSRSDataSource _srsDataSource;

  StatisticsDataSource(this._db, this._srsDataSource);

  /// Obtener total de cursos por usuario
  Future<int> getTotalCoursesByUser(String userId) =>
      _srsDataSource.contarCursos(userId);

  /// Obtener total de notas por usuario
  Future<int> getTotalNotesByUser(String userId) =>
      _srsDataSource.contarNotas(userId);

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

  /// Resumen real del repaso espaciado (pendientes, nuevas, racha, retención).
  Future<ResumenSrs> getResumenSrs(String userId) => _srsDataSource.resumen(userId);

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
