import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/srs/sm2.dart';
import '../models/note_model.dart';

/// DataSource local para notas
abstract class NotesLocalDataSource {
  Future<List<NoteModel>> getAllNotes(String userId);
  Future<List<NoteModel>> getNotesByCourse(String userId, String courseId);
  Future<NoteModel> getNote(String id);
  Future<void> saveNote(NoteModel note);
  Future<void> updateNote(NoteModel note);
  Future<void> deleteNote(String id);
  Future<List<NoteModel>> searchNotes(String userId, String query);
  Future<List<NoteModel>> getNotesByTags(String userId, List<String> tags);

  /// Escribe SOLO el estado SRS de una nota (sin tocar `updatedAt` ni el
  /// contenido). Es la única vía que puede "retroceder" el estado SRS
  /// (p. ej. reiniciar el progreso).
  Future<NoteModel> guardarSrs(String noteId, EstadoSrs estado);
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

  /// Decodifica todas las notas, saltando (y registrando) las corruptas en
  /// vez de romper la lista completa.
  List<NoteModel> _decodificarTodas() {
    final result = <NoteModel>[];
    for (final entry in _getNotes().entries) {
      try {
        result.add(NoteModel.fromJson(entry.value as Map<String, dynamic>));
      } catch (e) {
        debugPrint('NotesLocalDataSource: nota ${entry.key} ilegible: $e');
      }
    }
    return result;
  }

  /// Evita que una escritura con un estado SRS antiguo (una entidad cargada
  /// antes de repasar, o una nota recibida de Supabase, que no guarda SRS)
  /// borre el progreso de repaso: se conserva el SRS con el repaso más
  /// reciente.
  NoteModel _conservarSrs(NoteModel entrante, dynamic existenteJson) {
    if (existenteJson is! Map<String, dynamic>) return entrante;
    final NoteModel existente;
    try {
      existente = NoteModel.fromJson(existenteJson);
    } catch (_) {
      return entrante;
    }
    final previo = existente.srsLastReview;
    if (previo == null) return entrante;
    final nuevo = entrante.srsLastReview;
    if (nuevo == null || previo.isAfter(nuevo)) {
      return entrante.conSrs(existente.srs);
    }
    return entrante;
  }

  Future<void> _saveNotes(Map<String, dynamic> notes) async {
    await prefs.setString(_notesKey, json.encode(notes));
  }

  @override
  Future<List<NoteModel>> getAllNotes(String userId) async {
    try {
      final userNotes = _decodificarTodas()
          .where((note) => note.userId == userId)
          .toList();

      userNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return userNotes;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<List<NoteModel>> getNotesByCourse(String userId, String courseId) async {
    try {
      final courseNotes = _decodificarTodas()
          .where((note) => note.courseId == courseId && note.userId == userId)
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
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> saveNote(NoteModel note) async {
    try {
      final notes = _getNotes();
      notes[note.id] = _conservarSrs(note, notes[note.id]).toJson();
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
      notes[note.id] = _conservarSrs(note, notes[note.id]).toJson();
      await _saveNotes(notes);
    } on CacheException {
      rethrow;
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

  @override
  Future<NoteModel> guardarSrs(String noteId, EstadoSrs estado) async {
    try {
      final notes = _getNotes();
      final raw = notes[noteId];
      if (raw == null) throw const CacheException('Nota no encontrada');
      final actualizada =
          NoteModel.fromJson(raw as Map<String, dynamic>).conSrs(estado);
      notes[noteId] = actualizada.toJson();
      await _saveNotes(notes);
      return actualizada;
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }
}
