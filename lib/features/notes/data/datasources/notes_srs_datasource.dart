import '../../../../core/database/database.dart';
import '../../../../core/services/srs_service.dart';
import 'package:drift/drift.dart' as drift;

/// DataSource para operaciones SRS en notas usando Drift
class NotesSRSDataSource {
  final AppDatabase _db;

  NotesSRSDataSource(this._db);

  /// Actualiza una nota después de ser revisada
  ///
  /// rating: 0 = Again, 1 = Hard, 2 = Good, 3 = Easy
  Future<void> reviewNote(String noteId, int rating) async {
    // Obtener la nota actual
    final query = _db.select(_db.notes)
      ..where((n) => n.id.equals(noteId));

    final note = await query.getSingleOrNull();

    if (note == null) {
      throw Exception('Nota no encontrada');
    }

    // Calcular nuevo estado SRS
    final srsResult = SRSService.calculateNextReview(
      currentInterval: note.interval,
      currentEaseFactor: note.easeFactor,
      consecutiveCorrect: note.consecutiveCorrect,
      srsState: note.srsState,
      rating: rating,
    );

    // Actualizar la nota en la base de datos
    await (_db.update(_db.notes)..where((n) => n.id.equals(noteId))).write(
      NotesCompanion(
        interval: drift.Value(srsResult['interval'] as int),
        easeFactor: drift.Value(srsResult['easeFactor'] as double),
        consecutiveCorrect: drift.Value(srsResult['consecutiveCorrect'] as int),
        srsState: drift.Value(srsResult['srsState'] as String),
        nextReview: drift.Value(srsResult['nextReview'] as DateTime),
        lastReviewed: drift.Value(DateTime.now()),
        reviewCount: drift.Value(note.reviewCount + 1),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// Obtiene notas que necesitan ser revisadas
  Future<List<Note>> getNotesNeedingReview(String userId) async {
    final now = DateTime.now();

    final query = _db.select(_db.notes)
      ..where((n) => n.userId.equals(userId));

    final allNotes = await query.get();

    // Filtrar notas que necesitan revisión
    final notesNeedingReview = allNotes.where((note) {
      // Notas nuevas siempre necesitan revisión
      if (note.srsState == 'new') return true;

      // Notas con nextReview en el pasado
      if (note.nextReview != null && note.nextReview!.isBefore(now)) {
        return true;
      }

      return false;
    }).toList();

    // Ordenar por prioridad: vencidas primero, luego nuevas
    notesNeedingReview.sort((a, b) {
      // Priorizar notas vencidas
      if (a.nextReview != null && b.nextReview != null) {
        return a.nextReview!.compareTo(b.nextReview!);
      }

      // Nuevas al final
      if (a.srsState == 'new' && b.srsState != 'new') return 1;
      if (a.srsState != 'new' && b.srsState == 'new') return -1;

      return 0;
    });

    return notesNeedingReview;
  }

  /// Obtiene notas por curso que necesitan revisión
  Future<List<Note>> getNotesNeedingReviewByCourse(
    String userId,
    String courseId,
  ) async {
    final allNeedingReview = await getNotesNeedingReview(userId);
    return allNeedingReview.where((note) => note.courseId == courseId).toList();
  }

  /// Obtiene el conteo de notas que necesitan revisión
  Future<int> getNotesNeedingReviewCount(String userId) async {
    final notes = await getNotesNeedingReview(userId);
    return notes.length;
  }

  /// Obtiene estadísticas de retención por curso
  Future<Map<String, double>> getRetentionStatsByCourse(String userId) async {
    final query = _db.select(_db.notes)
      ..where((n) => n.userId.equals(userId));

    final allNotes = await query.get();

    // Agrupar por curso
    final Map<String, List<Note>> notesByCourse = {};
    for (final note in allNotes) {
      notesByCourse.putIfAbsent(note.courseId, () => []).add(note);
    }

    // Calcular retención promedio por curso
    final Map<String, double> retentionStats = {};
    notesByCourse.forEach((courseId, notes) {
      final totalRetention = notes.fold<double>(
        0.0,
        (sum, note) => sum + SRSService.estimateRetention(note.easeFactor),
      );
      retentionStats[courseId] = totalRetention / notes.length;
    });

    return retentionStats;
  }

  /// Reinicia el progreso SRS de una nota (útil para reaprender desde cero)
  Future<void> resetNoteProgress(String noteId) async {
    await (_db.update(_db.notes)..where((n) => n.id.equals(noteId))).write(
      NotesCompanion(
        interval: const drift.Value(0),
        easeFactor: const drift.Value(2.5),
        consecutiveCorrect: const drift.Value(0),
        srsState: const drift.Value('new'),
        nextReview: drift.Value(null),
        lastReviewed: drift.Value(null),
        reviewCount: const drift.Value(0),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// Obtiene estadísticas generales de SRS para un usuario
  Future<Map<String, dynamic>> getSRSStats(String userId) async {
    final query = _db.select(_db.notes)
      ..where((n) => n.userId.equals(userId));

    final allNotes = await query.get();

    final newCount = allNotes.where((n) => n.srsState == 'new').length;
    final learningCount = allNotes.where((n) => n.srsState == 'learning').length;
    final reviewCount = allNotes.where((n) => n.srsState == 'review').length;
    final relearnCount = allNotes.where((n) => n.srsState == 'relearning').length;

    final totalReviews = allNotes.fold<int>(
      0,
      (sum, note) => sum + note.reviewCount,
    );

    final avgEaseFactor = allNotes.isEmpty
        ? 2.5
        : allNotes.fold<double>(0.0, (sum, note) => sum + note.easeFactor) /
            allNotes.length;

    final avgRetention = SRSService.estimateRetention(avgEaseFactor);

    return {
      'totalNotes': allNotes.length,
      'newNotes': newCount,
      'learningNotes': learningCount,
      'reviewNotes': reviewCount,
      'relearnNotes': relearnCount,
      'totalReviews': totalReviews,
      'avgEaseFactor': avgEaseFactor,
      'avgRetention': avgRetention,
    };
  }

  /// Obtiene notas de aprendizaje (nuevas + aprendiendo)
  Future<List<Note>> getLearningNotes(String userId) async {
    final query = _db.select(_db.notes)
      ..where((n) => n.userId.equals(userId));

    final allNotes = await query.get();

    return allNotes
        .where((note) => note.srsState == 'new' || note.srsState == 'learning')
        .toList();
  }

  /// Obtiene notas en revisión
  Future<List<Note>> getReviewNotes(String userId) async {
    final query = _db.select(_db.notes)
      ..where((n) => n.userId.equals(userId));

    final allNotes = await query.get();

    return allNotes.where((note) => note.srsState == 'review').toList();
  }
}
