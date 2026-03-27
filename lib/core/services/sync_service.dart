import 'package:drift/drift.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/database.dart';

/// Service that handles bidirectional sync between local Drift DB and Supabase.
///
/// Uses 'updated_at' timestamps for last-write-wins conflict resolution.
/// Tracks last sync time in SharedPreferences.
/// Handles offline gracefully - queues changes and syncs when online.
class SyncService {
  final SupabaseClient _supabase;
  final AppDatabase _db;
  final SharedPreferences _prefs;
  final _log = Logger(printer: SimplePrinter());

  static const _lastSyncKey = 'last_sync_timestamp';

  SyncService({
    required SupabaseClient supabaseClient,
    required AppDatabase database,
    required SharedPreferences prefs,
  })  : _supabase = supabaseClient,
        _db = database,
        _prefs = prefs;

  /// Whether the user is authenticated with Supabase
  bool get _isAuthenticated => _supabase.auth.currentUser != null;

  /// The current user's ID from Supabase auth
  String? get _userId => _supabase.auth.currentUser?.id;

  /// Get last sync timestamp (ISO 8601 string)
  DateTime? get lastSyncTime {
    final stored = _prefs.getString(_lastSyncKey);
    if (stored == null) return null;
    return DateTime.tryParse(stored);
  }

  /// Save last sync timestamp
  Future<void> _saveLastSyncTime(DateTime time) async {
    await _prefs.setString(_lastSyncKey, time.toUtc().toIso8601String());
  }

  /// Perform a full sync: pull remote changes, then push local changes.
  /// Returns true if sync completed successfully.
  Future<bool> fullSync() async {
    if (!_isAuthenticated) {
      _log.w('[Sync] Not authenticated, skipping sync');
      return false;
    }

    try {
      final syncStart = DateTime.now().toUtc();

      await pullChanges();
      await pushChanges();

      await _saveLastSyncTime(syncStart);
      _log.i('[Sync] Full sync completed at $syncStart');
      return true;
    } catch (e, stack) {
      _log.e('[Sync] Full sync failed: $e\n$stack');
      return false;
    }
  }

  // ================================================================
  // PULL: Remote -> Local
  // ================================================================

  /// Pull changes from Supabase that are newer than our last sync.
  Future<void> pullChanges() async {
    if (!_isAuthenticated) return;

    final userId = _userId!;
    final since = lastSyncTime;

    _log.i('[Sync] Pulling changes since $since for user $userId');

    await _pullCourses(userId, since);
    await _pullNotes(userId, since);
    await _pullStudySessions(userId, since);
    await _pullPomodoroSessions(userId, since);
  }

  Future<void> _pullCourses(String userId, DateTime? since) async {
    try {
      var query = _supabase
          .from('courses')
          .select()
          .eq('user_id', userId);

      if (since != null) {
        query = query.gt('updated_at', since.toIso8601String());
      }

      final List<dynamic> rows = await query;
      _log.i('[Sync] Pulled ${rows.length} courses');

      for (final row in rows) {
        final remote = _remoteCourseToCompanion(row);
        final isDeleted = row['is_deleted'] as bool? ?? false;

        if (isDeleted) {
          // Soft-deleted remotely -> delete locally
          await (_db.delete(_db.courses)
                ..where((c) => c.id.equals(row['id'] as String)))
              .go();
        } else {
          // Upsert: check if local exists and compare updated_at
          final localRows = await (_db.select(_db.courses)
                ..where((c) => c.id.equals(row['id'] as String)))
              .get();

          if (localRows.isEmpty) {
            await _db.into(_db.courses).insert(remote);
          } else {
            final local = localRows.first;
            final remoteUpdated = DateTime.parse(row['updated_at'] as String);
            if (remoteUpdated.isAfter(local.updatedAt)) {
              await (_db.update(_db.courses)
                    ..where((c) => c.id.equals(row['id'] as String)))
                  .write(remote);
            }
          }
        }
      }
    } catch (e) {
      _log.e('[Sync] Pull courses failed: $e');
    }
  }

  Future<void> _pullNotes(String userId, DateTime? since) async {
    try {
      var query = _supabase
          .from('notes')
          .select()
          .eq('user_id', userId);

      if (since != null) {
        query = query.gt('updated_at', since.toIso8601String());
      }

      final List<dynamic> rows = await query;
      _log.i('[Sync] Pulled ${rows.length} notes');

      for (final row in rows) {
        final remote = _remoteNoteToCompanion(row);
        final isDeleted = row['is_deleted'] as bool? ?? false;

        if (isDeleted) {
          await (_db.delete(_db.notes)
                ..where((n) => n.id.equals(row['id'] as String)))
              .go();
        } else {
          final localRows = await (_db.select(_db.notes)
                ..where((n) => n.id.equals(row['id'] as String)))
              .get();

          if (localRows.isEmpty) {
            await _db.into(_db.notes).insert(remote);
          } else {
            final local = localRows.first;
            final remoteUpdated = DateTime.parse(row['updated_at'] as String);
            if (remoteUpdated.isAfter(local.updatedAt)) {
              await (_db.update(_db.notes)
                    ..where((n) => n.id.equals(row['id'] as String)))
                  .write(remote);
            }
          }
        }
      }
    } catch (e) {
      _log.e('[Sync] Pull notes failed: $e');
    }
  }

  Future<void> _pullStudySessions(String userId, DateTime? since) async {
    try {
      var query = _supabase
          .from('study_sessions')
          .select()
          .eq('user_id', userId);

      if (since != null) {
        query = query.gt('created_at', since.toIso8601String());
      }

      final List<dynamic> rows = await query;
      _log.i('[Sync] Pulled ${rows.length} study sessions');

      for (final row in rows) {
        final remote = _remoteStudySessionToCompanion(row);
        final localRows = await (_db.select(_db.studySessions)
              ..where((s) => s.id.equals(row['id'] as String)))
            .get();

        if (localRows.isEmpty) {
          await _db.into(_db.studySessions).insert(remote);
        }
        // Study sessions are append-only, no update needed
      }
    } catch (e) {
      _log.e('[Sync] Pull study sessions failed: $e');
    }
  }

  Future<void> _pullPomodoroSessions(String userId, DateTime? since) async {
    try {
      var query = _supabase
          .from('pomodoro_sessions')
          .select()
          .eq('user_id', userId);

      if (since != null) {
        query = query.gt('created_at', since.toIso8601String());
      }

      final List<dynamic> rows = await query;
      _log.i('[Sync] Pulled ${rows.length} pomodoro sessions');

      for (final row in rows) {
        final remote = _remotePomodoroSessionToCompanion(row);
        final localRows = await (_db.select(_db.pomodoroSessions)
              ..where((p) => p.id.equals(row['id'] as String)))
            .get();

        if (localRows.isEmpty) {
          await _db.into(_db.pomodoroSessions).insert(remote);
        }
      }
    } catch (e) {
      _log.e('[Sync] Pull pomodoro sessions failed: $e');
    }
  }

  // ================================================================
  // PUSH: Local -> Remote
  // ================================================================

  /// Push local changes to Supabase.
  /// Pushes records where synced_at is null or synced_at < updated_at.
  Future<void> pushChanges() async {
    if (!_isAuthenticated) return;

    final userId = _userId!;
    _log.i('[Sync] Pushing local changes for user $userId');

    await _pushUser(userId);
    await _pushCourses(userId);
    await _pushNotes(userId);
    await _pushStudySessions(userId);
    await _pushPomodoroSessions(userId);
  }

  Future<void> _pushUser(String userId) async {
    try {
      final localUsers = await (_db.select(_db.users)
            ..where((u) => u.id.equals(userId)))
          .get();

      if (localUsers.isEmpty) return;

      final user = localUsers.first;
      await _supabase.from('users').upsert({
        'id': user.id,
        'email': user.email,
        'name': user.name,
        'avatar_url': user.avatarUrl,
        'created_at': user.createdAt.toUtc().toIso8601String(),
        'updated_at': user.updatedAt.toUtc().toIso8601String(),
      });
    } catch (e) {
      _log.e('[Sync] Push user failed: $e');
    }
  }

  Future<void> _pushCourses(String userId) async {
    try {
      final localCourses = await (_db.select(_db.courses)
            ..where((c) => c.userId.equals(userId)))
          .get();

      if (localCourses.isEmpty) return;

      final now = DateTime.now().toUtc();
      final toUpsert = <Map<String, dynamic>>[];

      for (final course in localCourses) {
        // Push if never synced or updated after last sync
        if (course.syncedAt == null ||
            course.updatedAt.isAfter(course.syncedAt!)) {
          toUpsert.add({
            'id': course.id,
            'user_id': course.userId,
            'name': course.name,
            'description': course.description,
            'color': course.color,
            'is_favorite': course.isFavorite,
            'is_deleted': course.isDeleted,
            'created_at': course.createdAt.toUtc().toIso8601String(),
            'updated_at': course.updatedAt.toUtc().toIso8601String(),
            'synced_at': now.toIso8601String(),
          });
        }
      }

      if (toUpsert.isNotEmpty) {
        _log.i('[Sync] Pushing ${toUpsert.length} courses');
        await _supabase.from('courses').upsert(toUpsert);

        // Update local synced_at
        for (final data in toUpsert) {
          await (_db.update(_db.courses)
                ..where((c) => c.id.equals(data['id'] as String)))
              .write(CoursesCompanion(syncedAt: Value(now)));
        }
      }
    } catch (e) {
      _log.e('[Sync] Push courses failed: $e');
    }
  }

  Future<void> _pushNotes(String userId) async {
    try {
      final localNotes = await (_db.select(_db.notes)
            ..where((n) => n.userId.equals(userId)))
          .get();

      if (localNotes.isEmpty) return;

      final now = DateTime.now().toUtc();
      final toUpsert = <Map<String, dynamic>>[];

      for (final note in localNotes) {
        if (note.syncedAt == null ||
            note.updatedAt.isAfter(note.syncedAt!)) {
          toUpsert.add({
            'id': note.id,
            'course_id': note.courseId,
            'user_id': note.userId,
            'type': note.type,
            'front_content': note.frontContent,
            'back_content': note.backContent,
            'tags': note.tags,
            'difficulty': note.difficulty,
            'last_reviewed': note.lastReviewed?.toUtc().toIso8601String(),
            'next_review': note.nextReview?.toUtc().toIso8601String(),
            'review_count': note.reviewCount,
            'interval': note.interval,
            'ease_factor': note.easeFactor,
            'consecutive_correct': note.consecutiveCorrect,
            'srs_state': note.srsState,
            'is_deleted': note.isDeleted,
            'created_at': note.createdAt.toUtc().toIso8601String(),
            'updated_at': note.updatedAt.toUtc().toIso8601String(),
            'synced_at': now.toIso8601String(),
          });
        }
      }

      if (toUpsert.isNotEmpty) {
        _log.i('[Sync] Pushing ${toUpsert.length} notes');
        // Push in batches of 100 to avoid payload limits
        for (var i = 0; i < toUpsert.length; i += 100) {
          final batch = toUpsert.sublist(
            i,
            i + 100 > toUpsert.length ? toUpsert.length : i + 100,
          );
          await _supabase.from('notes').upsert(batch);
        }

        // Update local synced_at
        for (final data in toUpsert) {
          await (_db.update(_db.notes)
                ..where((n) => n.id.equals(data['id'] as String)))
              .write(NotesCompanion(syncedAt: Value(now)));
        }
      }
    } catch (e) {
      _log.e('[Sync] Push notes failed: $e');
    }
  }

  Future<void> _pushStudySessions(String userId) async {
    try {
      final localSessions = await (_db.select(_db.studySessions)
            ..where((s) => s.userId.equals(userId)))
          .get();

      if (localSessions.isEmpty) return;

      final now = DateTime.now().toUtc();
      final toUpsert = <Map<String, dynamic>>[];

      for (final session in localSessions) {
        if (session.syncedAt == null) {
          toUpsert.add({
            'id': session.id,
            'user_id': session.userId,
            'course_id': session.courseId,
            'cards_reviewed': session.cardsReviewed,
            'cards_correct': session.cardsCorrect,
            'duration_seconds': session.durationSeconds,
            'started_at': session.startedAt.toUtc().toIso8601String(),
            'ended_at': session.endedAt?.toUtc().toIso8601String(),
            'session_type': session.sessionType,
            'note_id': session.noteId,
            'synced_at': now.toIso8601String(),
          });
        }
      }

      if (toUpsert.isNotEmpty) {
        _log.i('[Sync] Pushing ${toUpsert.length} study sessions');
        await _supabase.from('study_sessions').upsert(toUpsert);

        for (final data in toUpsert) {
          await (_db.update(_db.studySessions)
                ..where((s) => s.id.equals(data['id'] as String)))
              .write(StudySessionsCompanion(syncedAt: Value(now)));
        }
      }
    } catch (e) {
      _log.e('[Sync] Push study sessions failed: $e');
    }
  }

  Future<void> _pushPomodoroSessions(String userId) async {
    try {
      final localSessions = await (_db.select(_db.pomodoroSessions)
            ..where((p) => p.userId.equals(userId)))
          .get();

      if (localSessions.isEmpty) return;

      final now = DateTime.now().toUtc();
      final toUpsert = <Map<String, dynamic>>[];

      for (final session in localSessions) {
        if (session.syncedAt == null) {
          toUpsert.add({
            'id': session.id,
            'user_id': session.userId,
            'course_id': session.courseId,
            'note_id': session.noteId,
            'work_duration': session.workDuration,
            'break_duration': session.breakDuration,
            'is_completed': session.isCompleted,
            'was_interrupted': session.wasInterrupted,
            'started_at': session.startedAt.toUtc().toIso8601String(),
            'completed_at': session.completedAt?.toUtc().toIso8601String(),
            'synced_at': now.toIso8601String(),
          });
        }
      }

      if (toUpsert.isNotEmpty) {
        _log.i('[Sync] Pushing ${toUpsert.length} pomodoro sessions');
        await _supabase.from('pomodoro_sessions').upsert(toUpsert);

        for (final data in toUpsert) {
          await (_db.update(_db.pomodoroSessions)
                ..where((p) => p.id.equals(data['id'] as String)))
              .write(PomodoroSessionsCompanion(syncedAt: Value(now)));
        }
      }
    } catch (e) {
      _log.e('[Sync] Push pomodoro sessions failed: $e');
    }
  }

  // ================================================================
  // REMOTE -> LOCAL CONVERTERS
  // ================================================================

  CoursesCompanion _remoteCourseToCompanion(Map<String, dynamic> row) {
    return CoursesCompanion(
      id: Value(row['id'] as String),
      userId: Value(row['user_id'] as String),
      name: Value(row['name'] as String),
      description: Value(row['description'] as String?),
      color: Value(row['color'] as String? ?? '#6366F1'),
      isFavorite: Value(row['is_favorite'] as bool? ?? false),
      isDeleted: Value(row['is_deleted'] as bool? ?? false),
      createdAt: Value(DateTime.parse(row['created_at'] as String)),
      updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
      syncedAt: Value(DateTime.now().toUtc()),
    );
  }

  NotesCompanion _remoteNoteToCompanion(Map<String, dynamic> row) {
    return NotesCompanion(
      id: Value(row['id'] as String),
      courseId: Value(row['course_id'] as String),
      userId: Value(row['user_id'] as String),
      type: Value(row['type'] as String),
      frontContent: Value(row['front_content'] as String),
      backContent: Value(row['back_content'] as String?),
      tags: Value(row['tags'] as String?),
      difficulty: Value(row['difficulty'] as int? ?? 0),
      lastReviewed: Value(row['last_reviewed'] != null
          ? DateTime.parse(row['last_reviewed'] as String)
          : null),
      nextReview: Value(row['next_review'] != null
          ? DateTime.parse(row['next_review'] as String)
          : null),
      reviewCount: Value(row['review_count'] as int? ?? 0),
      interval: Value(row['interval'] as int? ?? 0),
      easeFactor: Value((row['ease_factor'] as num?)?.toDouble() ?? 2.5),
      consecutiveCorrect: Value(row['consecutive_correct'] as int? ?? 0),
      srsState: Value(row['srs_state'] as String? ?? 'new'),
      isDeleted: Value(row['is_deleted'] as bool? ?? false),
      createdAt: Value(DateTime.parse(row['created_at'] as String)),
      updatedAt: Value(DateTime.parse(row['updated_at'] as String)),
      syncedAt: Value(DateTime.now().toUtc()),
    );
  }

  StudySessionsCompanion _remoteStudySessionToCompanion(
      Map<String, dynamic> row) {
    return StudySessionsCompanion(
      id: Value(row['id'] as String),
      userId: Value(row['user_id'] as String),
      courseId: Value(row['course_id'] as String),
      cardsReviewed: Value(row['cards_reviewed'] as int),
      cardsCorrect: Value(row['cards_correct'] as int),
      durationSeconds: Value(row['duration_seconds'] as int),
      startedAt: Value(DateTime.parse(row['started_at'] as String)),
      endedAt: Value(row['ended_at'] != null
          ? DateTime.parse(row['ended_at'] as String)
          : null),
      sessionType: Value(row['session_type'] as String? ?? 'review'),
      noteId: Value(row['note_id'] as String?),
      syncedAt: Value(DateTime.now().toUtc()),
    );
  }

  PomodoroSessionsCompanion _remotePomodoroSessionToCompanion(
      Map<String, dynamic> row) {
    return PomodoroSessionsCompanion(
      id: Value(row['id'] as String),
      userId: Value(row['user_id'] as String),
      courseId: Value(row['course_id'] as String?),
      noteId: Value(row['note_id'] as String?),
      workDuration: Value(row['work_duration'] as int? ?? 1500),
      breakDuration: Value(row['break_duration'] as int? ?? 300),
      isCompleted: Value(row['is_completed'] as bool? ?? false),
      wasInterrupted: Value(row['was_interrupted'] as bool? ?? false),
      startedAt: Value(DateTime.parse(row['started_at'] as String)),
      completedAt: Value(row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String)
          : null),
      syncedAt: Value(DateTime.now().toUtc()),
    );
  }
}
