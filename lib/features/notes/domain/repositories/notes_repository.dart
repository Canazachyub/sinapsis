import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/note.dart';

abstract class NotesRepository {
  Future<Either<Failure, List<Note>>> getAllNotes(String userId);
  Future<Either<Failure, List<Note>>> getNotesByCourse(String courseId);
  Future<Either<Failure, Note>> getNote(String id);
  Future<Either<Failure, Note>> createNote({
    required String courseId,
    required String userId,
    required String title,
    required String content,
    List<String>? tags,
  });
  Future<Either<Failure, Note>> updateNote(Note note);
  Future<Either<Failure, void>> deleteNote(String id);
  Future<Either<Failure, List<Note>>> searchNotes(String userId, String query);
  Future<Either<Failure, List<Note>>> getNotesByTags(String userId, List<String> tags);
}
