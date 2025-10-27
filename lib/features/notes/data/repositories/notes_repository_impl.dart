import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import '../datasources/notes_local_datasource.dart';
import '../models/note_model.dart';

class NotesRepositoryImpl implements NotesRepository {
  final NotesLocalDataSource localDataSource;

  NotesRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<Note>>> getAllNotes(String userId) async {
    try {
      final notes = await localDataSource.getAllNotes(userId);
      return Right(notes.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Note>>> getNotesByCourse(String courseId) async {
    try {
      final notes = await localDataSource.getNotesByCourse(courseId);
      return Right(notes.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Note>> getNote(String id) async {
    try {
      final note = await localDataSource.getNote(id);
      return Right(note.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Note>> createNote({
    required String courseId,
    required String userId,
    required String title,
    required String content,
    List<String>? tags,
  }) async {
    try {
      final now = DateTime.now();
      final note = NoteModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        courseId: courseId,
        userId: userId,
        title: title,
        content: content,
        tags: tags ?? [],
        occlusionMarks: const [],
        imageOcclusions: const [],
        createdAt: now,
        updatedAt: now,
      );

      await localDataSource.saveNote(note);
      return Right(note.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Note>> updateNote(Note note) async {
    try {
      final model = NoteModel.fromEntity(note).copyWith(
        updatedAt: DateTime.now(),
      );
      await localDataSource.updateNote(model);
      return Right(model.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteNote(String id) async {
    try {
      await localDataSource.deleteNote(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Note>>> searchNotes(
      String userId, String query) async {
    try {
      final notes = await localDataSource.searchNotes(userId, query);
      return Right(notes.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Note>>> getNotesByTags(
      String userId, List<String> tags) async {
    try {
      final notes = await localDataSource.getNotesByTags(userId, tags);
      return Right(notes.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
