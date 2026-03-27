import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sinapsis/core/errors/failures.dart';
import 'package:sinapsis/features/notes/domain/entities/note.dart';
import 'package:sinapsis/features/notes/domain/usecases/get_notes_by_course.dart';
import 'package:sinapsis/features/notes/domain/usecases/create_note.dart';
import 'package:sinapsis/features/notes/domain/usecases/update_note.dart';
import 'package:sinapsis/features/notes/domain/usecases/delete_note.dart';
import 'package:sinapsis/features/notes/presentation/bloc/notes_bloc.dart';

@GenerateMocks([GetNotesByCourse, CreateNote, UpdateNote, DeleteNote])
import 'notes_bloc_test.mocks.dart';

void main() {
  late NotesBloc bloc;
  late MockGetNotesByCourse mockGetNotesByCourse;
  late MockCreateNote mockCreateNote;
  late MockUpdateNote mockUpdateNote;
  late MockDeleteNote mockDeleteNote;

  final tNow = DateTime(2024, 1, 1);
  const tUserId = 'user-123';
  const tCourseId = 'course-456';

  final tNote = Note(
    id: 'note-1',
    courseId: tCourseId,
    userId: tUserId,
    title: 'Test Note',
    content: '{"ops":[{"insert":"Hello\\n"}]}',
    tags: const ['tag1', 'tag2'],
    createdAt: tNow,
    updatedAt: tNow,
  );

  final tNote2 = Note(
    id: 'note-2',
    courseId: tCourseId,
    userId: tUserId,
    title: 'Second Note',
    content: '{"ops":[{"insert":"World\\n"}]}',
    tags: const ['tag3'],
    createdAt: tNow,
    updatedAt: tNow,
  );

  setUp(() {
    mockGetNotesByCourse = MockGetNotesByCourse();
    mockCreateNote = MockCreateNote();
    mockUpdateNote = MockUpdateNote();
    mockDeleteNote = MockDeleteNote();
    bloc = NotesBloc(
      getNotesByCourse: mockGetNotesByCourse,
      createNote: mockCreateNote,
      updateNote: mockUpdateNote,
      deleteNote: mockDeleteNote,
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state should be NotesInitial', () {
    expect(bloc.state, isA<NotesInitial>());
  });

  group('LoadNotes', () {
    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoading, NotesLoaded] when getNotesByCourse succeeds',
      build: () {
        when(mockGetNotesByCourse(tUserId, tCourseId))
            .thenAnswer((_) async => Right([tNote, tNote2]));
        return bloc;
      },
      act: (bloc) => bloc.add(const LoadNotes(tUserId, tCourseId)),
      expect: () => [
        isA<NotesLoading>(),
        isA<NotesLoaded>()
            .having((s) => s.notes.length, 'notes count', 2)
            .having((s) => s.courseId, 'courseId', tCourseId),
      ],
      verify: (_) {
        verify(mockGetNotesByCourse(tUserId, tCourseId)).called(1);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoading, NotesError] when getNotesByCourse fails',
      build: () {
        when(mockGetNotesByCourse(tUserId, tCourseId))
            .thenAnswer((_) async => const Left(CacheFailure('Error de cache')));
        return bloc;
      },
      act: (bloc) => bloc.add(const LoadNotes(tUserId, tCourseId)),
      expect: () => [
        isA<NotesLoading>(),
        isA<NotesError>().having((s) => s.message, 'message', 'Error de cache'),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoading, NotesLoaded] with empty list when no notes exist',
      build: () {
        when(mockGetNotesByCourse(tUserId, tCourseId))
            .thenAnswer((_) async => const Right([]));
        return bloc;
      },
      act: (bloc) => bloc.add(const LoadNotes(tUserId, tCourseId)),
      expect: () => [
        isA<NotesLoading>(),
        isA<NotesLoaded>().having((s) => s.notes, 'notes', isEmpty),
      ],
    );
  });

  group('CreateNoteEvent', () {
    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoading, NotesLoaded] when create succeeds (reloads notes)',
      build: () {
        when(mockCreateNote(
          courseId: tCourseId,
          userId: tUserId,
          title: 'New Note',
          content: 'content',
          tags: const [],
        )).thenAnswer((_) async => Right(tNote));
        when(mockGetNotesByCourse(tUserId, tCourseId))
            .thenAnswer((_) async => Right([tNote]));
        return bloc;
      },
      act: (bloc) => bloc.add(const CreateNoteEvent(
        courseId: tCourseId,
        userId: tUserId,
        title: 'New Note',
        content: 'content',
      )),
      expect: () => [
        isA<NotesLoading>(),
        isA<NotesLoaded>(),
      ],
      verify: (_) {
        verify(mockCreateNote(
          courseId: tCourseId,
          userId: tUserId,
          title: 'New Note',
          content: 'content',
          tags: const [],
        )).called(1);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesError] when create fails',
      build: () {
        when(mockCreateNote(
          courseId: tCourseId,
          userId: tUserId,
          title: 'New Note',
          content: 'content',
          tags: const [],
        )).thenAnswer(
            (_) async => const Left(CacheFailure('Error al crear')));
        return bloc;
      },
      act: (bloc) => bloc.add(const CreateNoteEvent(
        courseId: tCourseId,
        userId: tUserId,
        title: 'New Note',
        content: 'content',
      )),
      expect: () => [
        isA<NotesError>()
            .having((s) => s.message, 'message', 'Error al crear'),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'passes tags correctly when creating a note',
      build: () {
        when(mockCreateNote(
          courseId: tCourseId,
          userId: tUserId,
          title: 'Tagged Note',
          content: 'content',
          tags: const ['physics', 'math'],
        )).thenAnswer((_) async => Right(tNote));
        when(mockGetNotesByCourse(tUserId, tCourseId))
            .thenAnswer((_) async => Right([tNote]));
        return bloc;
      },
      act: (bloc) => bloc.add(const CreateNoteEvent(
        courseId: tCourseId,
        userId: tUserId,
        title: 'Tagged Note',
        content: 'content',
        tags: ['physics', 'math'],
      )),
      expect: () => [
        isA<NotesLoading>(),
        isA<NotesLoaded>(),
      ],
    );
  });

  group('UpdateNoteEvent', () {
    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoading, NotesLoaded] when update succeeds (reloads)',
      build: () {
        final updatedNote = tNote.copyWith(title: 'Updated Title');
        when(mockUpdateNote(updatedNote))
            .thenAnswer((_) async => Right(updatedNote));
        when(mockGetNotesByCourse(tUserId, tCourseId))
            .thenAnswer((_) async => Right([updatedNote]));
        return bloc;
      },
      act: (bloc) => bloc.add(
          UpdateNoteEvent(tNote.copyWith(title: 'Updated Title'))),
      expect: () => [
        isA<NotesLoading>(),
        isA<NotesLoaded>(),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesError] when update fails',
      build: () {
        when(mockUpdateNote(tNote))
            .thenAnswer((_) async => const Left(CacheFailure('Update error')));
        return bloc;
      },
      act: (bloc) => bloc.add(UpdateNoteEvent(tNote)),
      expect: () => [
        isA<NotesError>()
            .having((s) => s.message, 'message', 'Update error'),
      ],
    );
  });

  group('DeleteNoteEvent', () {
    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoading, NotesLoaded] when delete succeeds (reloads)',
      build: () {
        when(mockDeleteNote('note-1'))
            .thenAnswer((_) async => const Right(null));
        when(mockGetNotesByCourse(tUserId, tCourseId))
            .thenAnswer((_) async => const Right([]));
        return bloc;
      },
      act: (bloc) =>
          bloc.add(const DeleteNoteEvent('note-1', tUserId, tCourseId)),
      expect: () => [
        isA<NotesLoading>(),
        isA<NotesLoaded>().having((s) => s.notes, 'notes', isEmpty),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesError] when delete fails',
      build: () {
        when(mockDeleteNote('note-1'))
            .thenAnswer((_) async => const Left(CacheFailure('Delete error')));
        return bloc;
      },
      act: (bloc) =>
          bloc.add(const DeleteNoteEvent('note-1', tUserId, tCourseId)),
      expect: () => [
        isA<NotesError>()
            .having((s) => s.message, 'message', 'Delete error'),
      ],
    );
  });

  group('NotesState equality', () {
    test('NotesLoaded with same notes are equal', () {
      final state1 = NotesLoaded([tNote], tCourseId);
      final state2 = NotesLoaded([tNote], tCourseId);
      expect(state1, equals(state2));
    });

    test('NotesLoaded with different notes are not equal', () {
      final state1 = NotesLoaded([tNote], tCourseId);
      final state2 = NotesLoaded([tNote2], tCourseId);
      expect(state1, isNot(equals(state2)));
    });

    test('NotesError with same message are equal', () {
      const state1 = NotesError('error');
      const state2 = NotesError('error');
      expect(state1, equals(state2));
    });
  });

  group('NotesEvent equality', () {
    test('LoadNotes with same params are equal', () {
      const event1 = LoadNotes(tUserId, tCourseId);
      const event2 = LoadNotes(tUserId, tCourseId);
      expect(event1, equals(event2));
    });

    test('LoadNotes with different params are not equal', () {
      const event1 = LoadNotes(tUserId, tCourseId);
      const event2 = LoadNotes('other-user', tCourseId);
      expect(event1, isNot(equals(event2)));
    });

    test('DeleteNoteEvent props are correct', () {
      const event = DeleteNoteEvent('note-1', tUserId, tCourseId);
      expect(event.props, ['note-1', tUserId, tCourseId]);
    });
  });
}
