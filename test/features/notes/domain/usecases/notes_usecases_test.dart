import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sinapsis/core/errors/failures.dart';
import 'package:sinapsis/features/notes/domain/entities/note.dart';
import 'package:sinapsis/features/notes/domain/repositories/notes_repository.dart';
import 'package:sinapsis/features/notes/domain/usecases/get_notes_by_course.dart';
import 'package:sinapsis/features/notes/domain/usecases/create_note.dart';
import 'package:sinapsis/features/notes/domain/usecases/update_note.dart';
import 'package:sinapsis/features/notes/domain/usecases/delete_note.dart';

@GenerateMocks([NotesRepository])
import 'notes_usecases_test.mocks.dart';

void main() {
  late MockNotesRepository mockRepository;
  final tNow = DateTime(2024, 1, 1);
  const tUserId = 'user-123';
  const tCourseId = 'course-456';

  final tNote = Note(
    id: 'note-1',
    courseId: tCourseId,
    userId: tUserId,
    title: 'Test Note',
    content: '{"ops":[{"insert":"Hello\\n"}]}',
    tags: const ['tag1'],
    createdAt: tNow,
    updatedAt: tNow,
  );

  setUp(() {
    mockRepository = MockNotesRepository();
  });

  group('GetNotesByCourse', () {
    late GetNotesByCourse useCase;

    setUp(() {
      useCase = GetNotesByCourse(mockRepository);
    });

    test('should return list of notes from the repository', () async {
      when(mockRepository.getNotesByCourse(tUserId, tCourseId))
          .thenAnswer((_) async => Right([tNote]));

      final result = await useCase(tUserId, tCourseId);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should be Right'),
        (notes) {
          expect(notes.length, 1);
          expect(notes.first, tNote);
        },
      );
      verify(mockRepository.getNotesByCourse(tUserId, tCourseId)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return failure when repository fails', () async {
      when(mockRepository.getNotesByCourse(tUserId, tCourseId))
          .thenAnswer((_) async => const Left(CacheFailure('Error')));

      final result = await useCase(tUserId, tCourseId);

      expect(result, const Left(CacheFailure('Error')));
    });

    test('should return empty list when no notes exist', () async {
      when(mockRepository.getNotesByCourse(tUserId, tCourseId))
          .thenAnswer((_) async => const Right([]));

      final result = await useCase(tUserId, tCourseId);

      result.fold(
        (failure) => fail('Should not return failure'),
        (notes) => expect(notes, isEmpty),
      );
    });
  });

  group('CreateNote', () {
    late CreateNote useCase;

    setUp(() {
      useCase = CreateNote(mockRepository);
    });

    test('should create a note through the repository', () async {
      when(mockRepository.createNote(
        courseId: tCourseId,
        userId: tUserId,
        title: 'New Note',
        content: 'content',
        tags: const ['tag1'],
      )).thenAnswer((_) async => Right(tNote));

      final result = await useCase(
        courseId: tCourseId,
        userId: tUserId,
        title: 'New Note',
        content: 'content',
        tags: const ['tag1'],
      );

      expect(result.isRight(), isTrue);
      verify(mockRepository.createNote(
        courseId: tCourseId,
        userId: tUserId,
        title: 'New Note',
        content: 'content',
        tags: const ['tag1'],
      )).called(1);
    });

    test('should pass null tags when not provided', () async {
      when(mockRepository.createNote(
        courseId: tCourseId,
        userId: tUserId,
        title: 'No Tags',
        content: 'content',
        tags: null,
      )).thenAnswer((_) async => Right(tNote));

      final result = await useCase(
        courseId: tCourseId,
        userId: tUserId,
        title: 'No Tags',
        content: 'content',
      );

      expect(result.isRight(), isTrue);
    });

    test('should return failure when repository fails to create', () async {
      when(mockRepository.createNote(
        courseId: tCourseId,
        userId: tUserId,
        title: 'Fail',
        content: 'content',
        tags: null,
      )).thenAnswer(
          (_) async => const Left(CacheFailure('Cannot save')));

      final result = await useCase(
        courseId: tCourseId,
        userId: tUserId,
        title: 'Fail',
        content: 'content',
      );

      expect(result, const Left(CacheFailure('Cannot save')));
    });
  });

  group('UpdateNote', () {
    late UpdateNote useCase;

    setUp(() {
      useCase = UpdateNote(mockRepository);
    });

    test('should update a note through the repository', () async {
      final updatedNote = tNote.copyWith(title: 'Updated');
      when(mockRepository.updateNote(updatedNote))
          .thenAnswer((_) async => Right(updatedNote));

      final result = await useCase(updatedNote);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (note) => expect(note.title, 'Updated'),
      );
    });

    test('should return failure when note not found', () async {
      when(mockRepository.updateNote(tNote))
          .thenAnswer((_) async => const Left(CacheFailure('Nota no encontrada')));

      final result = await useCase(tNote);

      expect(result.isLeft(), isTrue);
    });
  });

  group('DeleteNote', () {
    late DeleteNote useCase;

    setUp(() {
      useCase = DeleteNote(mockRepository);
    });

    test('should delete a note through the repository', () async {
      when(mockRepository.deleteNote('note-1'))
          .thenAnswer((_) async => const Right(null));

      final result = await useCase('note-1');

      expect(result, const Right(null));
      verify(mockRepository.deleteNote('note-1')).called(1);
    });

    test('should return failure when delete fails', () async {
      when(mockRepository.deleteNote('non-existent'))
          .thenAnswer((_) async => const Left(CacheFailure('Not found')));

      final result = await useCase('non-existent');

      expect(result.isLeft(), isTrue);
    });
  });

  group('Note entity', () {
    test('copyWith should create a copy with updated fields', () {
      final updatedNote = tNote.copyWith(
        title: 'New Title',
        tags: const ['new-tag'],
      );

      expect(updatedNote.title, 'New Title');
      expect(updatedNote.tags, ['new-tag']);
      expect(updatedNote.id, tNote.id);
      expect(updatedNote.content, tNote.content);
    });

    test('two Notes with same props should be equal', () {
      final note1 = Note(
        id: '1',
        courseId: 'c1',
        userId: 'u1',
        title: 'T',
        content: 'C',
        createdAt: tNow,
        updatedAt: tNow,
      );
      final note2 = Note(
        id: '1',
        courseId: 'c1',
        userId: 'u1',
        title: 'T',
        content: 'C',
        createdAt: tNow,
        updatedAt: tNow,
      );
      expect(note1, equals(note2));
    });

    test('OcclusionMark equality', () {
      const mark1 = OcclusionMark(id: '1', startIndex: 0, endIndex: 5);
      const mark2 = OcclusionMark(id: '1', startIndex: 0, endIndex: 5);
      const mark3 = OcclusionMark(id: '1', startIndex: 0, endIndex: 10);
      expect(mark1, equals(mark2));
      expect(mark1, isNot(equals(mark3)));
    });

    test('ImageOcclusion equality', () {
      const occ1 = ImageOcclusion(
        id: '1', imageUrl: 'url', x: 0.1, y: 0.2, width: 0.3, height: 0.4,
      );
      const occ2 = ImageOcclusion(
        id: '1', imageUrl: 'url', x: 0.1, y: 0.2, width: 0.3, height: 0.4,
      );
      expect(occ1, equals(occ2));
    });

    test('Note with occlusion marks preserves them in copyWith', () {
      const marks = [OcclusionMark(id: 'm1', startIndex: 0, endIndex: 5)];
      final noteWithMarks = tNote.copyWith(occlusionMarks: marks);
      final copy = noteWithMarks.copyWith(title: 'Changed');
      expect(copy.occlusionMarks, marks);
      expect(copy.title, 'Changed');
    });
  });
}
