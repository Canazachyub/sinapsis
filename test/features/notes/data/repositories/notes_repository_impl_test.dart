import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sinapsis/core/errors/exceptions.dart';
import 'package:sinapsis/core/errors/failures.dart';
import 'package:sinapsis/features/notes/data/datasources/notes_local_datasource.dart';
import 'package:sinapsis/features/notes/data/models/note_model.dart';
import 'package:sinapsis/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:sinapsis/features/notes/domain/entities/note.dart';

@GenerateMocks([NotesLocalDataSource])
import 'notes_repository_impl_test.mocks.dart';

void main() {
  late NotesRepositoryImpl repository;
  late MockNotesLocalDataSource mockDataSource;

  final tNow = DateTime(2024, 1, 1);
  const tUserId = 'user-123';
  const tCourseId = 'course-456';

  final tNoteModel = NoteModel(
    id: 'note-1',
    courseId: tCourseId,
    userId: tUserId,
    title: 'Test Note',
    content: 'Test content',
    tags: const ['tag1'],
    occlusionMarks: const [],
    imageOcclusions: const [],
    createdAt: tNow,
    updatedAt: tNow,
  );

  setUp(() {
    mockDataSource = MockNotesLocalDataSource();
    repository = NotesRepositoryImpl(localDataSource: mockDataSource);
  });

  group('getAllNotes', () {
    test('should return list of Note entities on success', () async {
      when(mockDataSource.getAllNotes(tUserId))
          .thenAnswer((_) async => [tNoteModel]);

      final result = await repository.getAllNotes(tUserId);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should be Right'),
        (notes) {
          expect(notes.length, 1);
          expect(notes.first, isA<Note>());
          expect(notes.first.title, 'Test Note');
        },
      );
    });

    test('should return CacheFailure on CacheException', () async {
      when(mockDataSource.getAllNotes(tUserId))
          .thenThrow(const CacheException('DB error'));

      final result = await repository.getAllNotes(tUserId);

      expect(result, const Left(CacheFailure('DB error')));
    });
  });

  group('getNotesByCourse', () {
    test('should return filtered notes on success', () async {
      when(mockDataSource.getNotesByCourse(tUserId, tCourseId))
          .thenAnswer((_) async => [tNoteModel]);

      final result = await repository.getNotesByCourse(tUserId, tCourseId);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should be Right'),
        (notes) => expect(notes.length, 1),
      );
      verify(mockDataSource.getNotesByCourse(tUserId, tCourseId)).called(1);
    });

    test('should return empty list when no notes for course', () async {
      when(mockDataSource.getNotesByCourse(tUserId, 'no-course'))
          .thenAnswer((_) async => []);

      final result = await repository.getNotesByCourse(tUserId, 'no-course');

      result.fold(
        (_) => fail('Should be Right'),
        (notes) => expect(notes, isEmpty),
      );
    });

    test('should return CacheFailure on exception', () async {
      when(mockDataSource.getNotesByCourse(tUserId, tCourseId))
          .thenThrow(const CacheException('Read error'));

      final result = await repository.getNotesByCourse(tUserId, tCourseId);

      expect(result.isLeft(), isTrue);
    });
  });

  group('getNote', () {
    test('should return single Note entity on success', () async {
      when(mockDataSource.getNote('note-1'))
          .thenAnswer((_) async => tNoteModel);

      final result = await repository.getNote('note-1');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should be Right'),
        (note) => expect(note.id, 'note-1'),
      );
    });

    test('should return CacheFailure when note not found', () async {
      when(mockDataSource.getNote('non-existent'))
          .thenThrow(const CacheException('Nota no encontrada'));

      final result = await repository.getNote('non-existent');

      expect(result, const Left(CacheFailure('Nota no encontrada')));
    });
  });

  group('createNote', () {
    test('should create note and return entity on success', () async {
      when(mockDataSource.saveNote(any)).thenAnswer((_) async {});

      final result = await repository.createNote(
        courseId: tCourseId,
        userId: tUserId,
        title: 'New Note',
        content: 'content',
        tags: ['tag1'],
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should be Right'),
        (note) {
          expect(note.title, 'New Note');
          expect(note.courseId, tCourseId);
          expect(note.userId, tUserId);
          expect(note.tags, ['tag1']);
        },
      );
      verify(mockDataSource.saveNote(any)).called(1);
    });

    test('should create note with empty tags when tags is null', () async {
      when(mockDataSource.saveNote(any)).thenAnswer((_) async {});

      final result = await repository.createNote(
        courseId: tCourseId,
        userId: tUserId,
        title: 'No Tags',
        content: 'content',
      );

      result.fold(
        (_) => fail('Should be Right'),
        (note) => expect(note.tags, isEmpty),
      );
    });

    test('should return CacheFailure on save error', () async {
      when(mockDataSource.saveNote(any))
          .thenThrow(const CacheException('Write error'));

      final result = await repository.createNote(
        courseId: tCourseId,
        userId: tUserId,
        title: 'Fail',
        content: 'content',
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('updateNote', () {
    test('should update note and return updated entity', () async {
      when(mockDataSource.updateNote(any)).thenAnswer((_) async {});

      final noteToUpdate = tNoteModel.toEntity().copyWith(title: 'Updated');
      final result = await repository.updateNote(noteToUpdate);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should be Right'),
        (note) => expect(note.title, 'Updated'),
      );
    });

    test('should return CacheFailure when note does not exist', () async {
      when(mockDataSource.updateNote(any))
          .thenThrow(const CacheException('Nota no encontrada'));

      final result = await repository.updateNote(tNoteModel.toEntity());

      expect(result.isLeft(), isTrue);
    });
  });

  group('deleteNote', () {
    test('should delete note and return Right(null) on success', () async {
      when(mockDataSource.deleteNote('note-1')).thenAnswer((_) async {});

      final result = await repository.deleteNote('note-1');

      expect(result, const Right(null));
      verify(mockDataSource.deleteNote('note-1')).called(1);
    });

    test('should return CacheFailure on delete error', () async {
      when(mockDataSource.deleteNote('note-1'))
          .thenThrow(const CacheException('Delete error'));

      final result = await repository.deleteNote('note-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('searchNotes', () {
    test('should return matching notes on success', () async {
      when(mockDataSource.searchNotes(tUserId, 'Test'))
          .thenAnswer((_) async => [tNoteModel]);

      final result = await repository.searchNotes(tUserId, 'Test');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should be Right'),
        (notes) => expect(notes.length, 1),
      );
    });

    test('should return CacheFailure on search error', () async {
      when(mockDataSource.searchNotes(tUserId, 'query'))
          .thenThrow(const CacheException('Search error'));

      final result = await repository.searchNotes(tUserId, 'query');

      expect(result.isLeft(), isTrue);
    });
  });

  group('getNotesByTags', () {
    test('should return notes matching all tags', () async {
      when(mockDataSource.getNotesByTags(tUserId, ['tag1']))
          .thenAnswer((_) async => [tNoteModel]);

      final result = await repository.getNotesByTags(tUserId, ['tag1']);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should be Right'),
        (notes) => expect(notes.length, 1),
      );
    });

    test('should return CacheFailure on error', () async {
      when(mockDataSource.getNotesByTags(tUserId, ['tag1']))
          .thenThrow(const CacheException('Tag error'));

      final result = await repository.getNotesByTags(tUserId, ['tag1']);

      expect(result.isLeft(), isTrue);
    });
  });
}
