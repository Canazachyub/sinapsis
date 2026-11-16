import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/courses/data/models/course_model.dart';
import '../../features/notes/data/models/note_model.dart';
import '../../features/notes/data/datasources/notes_local_datasource.dart';
import '../../features/courses/data/datasources/courses_local_datasource.dart';

/// Helper que sincroniza notas y cursos directamente con Supabase.
/// Las operaciones fallan silenciosamente si no hay red o usuario no autenticado
/// para no bloquear el uso offline.
class SupabaseSyncHelper {
  final SupabaseClient _client;
  final NotesLocalDataSource _notesLocal;
  final CoursesLocalDataSource _coursesLocal;

  SupabaseSyncHelper({
    required SupabaseClient client,
    required NotesLocalDataSource notesLocal,
    required CoursesLocalDataSource coursesLocal,
  })  : _client = client,
        _notesLocal = notesLocal,
        _coursesLocal = coursesLocal;

  bool get _isAuth => _client.auth.currentUser != null;
  String? get _userId => _client.auth.currentUser?.id;

  // ===== NOTES =====

  Future<void> pushNote(NoteModel note) async {
    if (!_isAuth) return;
    try {
      await _client.from('app_notes').upsert({
        'id': note.id,
        'course_id': note.courseId,
        'user_id': note.userId,
        'title': note.title,
        'content': note.content,
        'tags': note.tags,
        'occlusion_marks': note.occlusionMarks.map((m) => m.toJson()).toList(),
        'image_occlusions': note.imageOcclusions.map((o) => o.toJson()).toList(),
        'is_deleted': false,
        'created_at': note.createdAt.toUtc().toIso8601String(),
        'updated_at': note.updatedAt.toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> deleteNoteRemote(String noteId) async {
    if (!_isAuth) return;
    try {
      await _client
          .from('app_notes')
          .update({'is_deleted': true, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', noteId);
    } catch (_) {}
  }

  Future<void> pullNotes() async {
    if (!_isAuth) return;
    try {
      final rows = await _client
          .from('app_notes')
          .select()
          .eq('user_id', _userId!)
          .eq('is_deleted', false);

      for (final row in (rows as List)) {
        final r = row as Map<String, dynamic>;
        final note = NoteModel(
          id: r['id'] as String,
          courseId: r['course_id'] as String,
          userId: r['user_id'] as String,
          title: r['title'] as String? ?? '',
          content: r['content'] as String? ?? '',
          tags: _parseStringList(r['tags']),
          occlusionMarks: _parseOcclusionMarks(r['occlusion_marks']),
          imageOcclusions: _parseImageOcclusions(r['image_occlusions']),
          createdAt: DateTime.parse(r['created_at'] as String),
          updatedAt: DateTime.parse(r['updated_at'] as String),
        );
        await _notesLocal.saveNote(note);
      }
    } catch (_) {}
  }

  // ===== COURSES =====

  Future<void> pushCourse(CourseModel course) async {
    if (!_isAuth) return;
    try {
      await _client.from('courses').upsert({
        'id': course.id,
        'user_id': course.userId,
        'name': course.name,
        'description': course.description,
        'color': course.color,
        'is_favorite': course.isFavorite,
        'is_deleted': false,
        'created_at': course.createdAt.toUtc().toIso8601String(),
        'updated_at': course.updatedAt.toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> deleteCourseRemote(String courseId) async {
    if (!_isAuth) return;
    try {
      await _client
          .from('courses')
          .update({'is_deleted': true, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', courseId);
    } catch (_) {}
  }

  Future<void> pullCourses() async {
    if (!_isAuth) return;
    try {
      final rows = await _client
          .from('courses')
          .select()
          .eq('user_id', _userId!)
          .eq('is_deleted', false);

      for (final row in (rows as List)) {
        final r = row as Map<String, dynamic>;
        final course = CourseModel(
          id: r['id'] as String,
          userId: r['user_id'] as String,
          name: r['name'] as String,
          description: r['description'] as String?,
          color: r['color'] as String? ?? '#6366F1',
          isFavorite: r['is_favorite'] as bool? ?? false,
          createdAt: DateTime.parse(r['created_at'] as String),
          updatedAt: DateTime.parse(r['updated_at'] as String),
        );
        await _coursesLocal.saveCourse(course);
      }
    } catch (_) {}
  }

  /// Pull completo al iniciar sesión
  Future<void> pullAll() async {
    await pullCourses();
    await pullNotes();
  }

  // ===== Helpers =====

  List<String> _parseStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  List<OcclusionMarkModel> _parseOcclusionMarks(dynamic raw) {
    if (raw == null) return [];
    List list = raw is List
        ? raw
        : (raw is String ? (jsonDecode(raw) as List? ?? []) : []);
    return list
        .map((e) => OcclusionMarkModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<ImageOcclusionModel> _parseImageOcclusions(dynamic raw) {
    if (raw == null) return [];
    List list = raw is List
        ? raw
        : (raw is String ? (jsonDecode(raw) as List? ?? []) : []);
    return list
        .map((e) => ImageOcclusionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
