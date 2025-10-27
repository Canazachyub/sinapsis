import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/note_model.dart';

/// DataSource local para notas
abstract class NotesLocalDataSource {
  Future<List<NoteModel>> getAllNotes(String userId);
  Future<List<NoteModel>> getNotesByCourse(String courseId);
  Future<NoteModel> getNote(String id);
  Future<void> saveNote(NoteModel note);
  Future<void> updateNote(NoteModel note);
  Future<void> deleteNote(String id);
  Future<List<NoteModel>> searchNotes(String userId, String query);
  Future<List<NoteModel>> getNotesByTags(String userId, List<String> tags);
}

/// Implementación con SharedPreferences
class NotesLocalDataSourceImpl implements NotesLocalDataSource {
  final SharedPreferences prefs;
  static const String _notesKey = 'NOTES_DATA';

  NotesLocalDataSourceImpl({required this.prefs});

  Map<String, dynamic> _getNotes() {
    final notesJson = prefs.getString(_notesKey);
    if (notesJson == null) return {};
    return json.decode(notesJson) as Map<String, dynamic>;
  }

  Future<void> _saveNotes(Map<String, dynamic> notes) async {
    await prefs.setString(_notesKey, json.encode(notes));
  }

  @override
  Future<List<NoteModel>> getAllNotes(String userId) async {
    try {
      final notes = _getNotes();
      final userNotes = notes.values
          .map((json) => NoteModel.fromJson(json as Map<String, dynamic>))
          .where((note) => note.userId == userId)
          .toList();

      userNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return userNotes;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<List<NoteModel>> getNotesByCourse(String courseId) async {
    try {
      final notes = _getNotes();
      final courseNotes = notes.values
          .map((json) => NoteModel.fromJson(json as Map<String, dynamic>))
          .where((note) => note.courseId == courseId)
          .toList();

      courseNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return courseNotes;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<NoteModel> getNote(String id) async {
    try {
      final notes = _getNotes();
      final noteJson = notes[id];
      if (noteJson == null) {
        throw const CacheException('Nota no encontrada');
      }
      return NoteModel.fromJson(noteJson as Map<String, dynamic>);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> saveNote(NoteModel note) async {
    try {
      final notes = _getNotes();
      notes[note.id] = note.toJson();
      await _saveNotes(notes);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> updateNote(NoteModel note) async {
    try {
      final notes = _getNotes();
      if (!notes.containsKey(note.id)) {
        throw const CacheException('Nota no encontrada');
      }
      notes[note.id] = note.toJson();
      await _saveNotes(notes);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    try {
      final notes = _getNotes();
      notes.remove(id);
      await _saveNotes(notes);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<List<NoteModel>> searchNotes(String userId, String query) async {
    try {
      final allNotes = await getAllNotes(userId);
      final lowerQuery = query.toLowerCase();

      return allNotes.where((note) {
        final titleMatch = note.title.toLowerCase().contains(lowerQuery);
        final contentMatch = note.content.toLowerCase().contains(lowerQuery);
        final tagsMatch = note.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        return titleMatch || contentMatch || tagsMatch;
      }).toList();
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<List<NoteModel>> getNotesByTags(String userId, List<String> tags) async {
    try {
      final allNotes = await getAllNotes(userId);

      return allNotes.where((note) {
        return tags.every((tag) => note.tags.contains(tag));
      }).toList();
    } catch (e) {
      throw CacheException(e.toString());
    }
  }
}
