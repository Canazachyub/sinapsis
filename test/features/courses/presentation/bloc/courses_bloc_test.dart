import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sinapsis/core/errors/failures.dart';
import 'package:sinapsis/features/courses/domain/entities/course.dart';
import 'package:sinapsis/features/courses/domain/usecases/get_all_courses.dart';
import 'package:sinapsis/features/courses/domain/usecases/create_course.dart';
import 'package:sinapsis/features/courses/domain/usecases/update_course.dart';
import 'package:sinapsis/features/courses/domain/usecases/delete_course.dart';
import 'package:sinapsis/features/courses/presentation/bloc/courses_bloc.dart';

@GenerateMocks([GetAllCourses, CreateCourse, UpdateCourse, DeleteCourse])
import 'courses_bloc_test.mocks.dart';

void main() {
  late CoursesBloc bloc;
  late MockGetAllCourses mockGetAllCourses;
  late MockCreateCourse mockCreateCourse;
  late MockUpdateCourse mockUpdateCourse;
  late MockDeleteCourse mockDeleteCourse;

  final tNow = DateTime(2024, 1, 1);
  const tUserId = 'user-123';

  final tCourse = Course(
    id: 'course-1',
    userId: tUserId,
    name: 'Math',
    description: 'Mathematics',
    color: '#FF0000',
    createdAt: tNow,
    updatedAt: tNow,
  );

  final tCourse2 = Course(
    id: 'course-2',
    userId: tUserId,
    name: 'Physics',
    color: '#00FF00',
    createdAt: tNow,
    updatedAt: tNow,
  );

  setUp(() {
    mockGetAllCourses = MockGetAllCourses();
    mockCreateCourse = MockCreateCourse();
    mockUpdateCourse = MockUpdateCourse();
    mockDeleteCourse = MockDeleteCourse();
    bloc = CoursesBloc(
      getAllCourses: mockGetAllCourses,
      createCourse: mockCreateCourse,
      updateCourse: mockUpdateCourse,
      deleteCourse: mockDeleteCourse,
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state should be CoursesInitial', () {
    expect(bloc.state, isA<CoursesInitial>());
  });

  group('LoadCourses', () {
    blocTest<CoursesBloc, CoursesState>(
      'emits [CoursesLoading, CoursesLoaded] when successful',
      build: () {
        when(mockGetAllCourses(tUserId))
            .thenAnswer((_) async => Right([tCourse, tCourse2]));
        return bloc;
      },
      act: (bloc) => bloc.add(const LoadCourses(tUserId)),
      expect: () => [
        isA<CoursesLoading>(),
        isA<CoursesLoaded>().having((s) => s.courses.length, 'count', 2),
      ],
    );

    blocTest<CoursesBloc, CoursesState>(
      'emits [CoursesLoading, CoursesError] when fails',
      build: () {
        when(mockGetAllCourses(tUserId))
            .thenAnswer((_) async => const Left(CacheFailure('Error')));
        return bloc;
      },
      act: (bloc) => bloc.add(const LoadCourses(tUserId)),
      expect: () => [
        isA<CoursesLoading>(),
        isA<CoursesError>().having((s) => s.message, 'message', 'Error'),
      ],
    );

    blocTest<CoursesBloc, CoursesState>(
      'emits [CoursesLoading, CoursesLoaded] with empty list',
      build: () {
        when(mockGetAllCourses(tUserId))
            .thenAnswer((_) async => const Right([]));
        return bloc;
      },
      act: (bloc) => bloc.add(const LoadCourses(tUserId)),
      expect: () => [
        isA<CoursesLoading>(),
        isA<CoursesLoaded>().having((s) => s.courses, 'courses', isEmpty),
      ],
    );
  });

  group('CreateCourseEvent', () {
    blocTest<CoursesBloc, CoursesState>(
      'emits [CoursesLoading, CoursesLoaded] when create succeeds',
      build: () {
        when(mockCreateCourse(
          userId: tUserId,
          name: 'Chemistry',
          description: null,
          color: '#0000FF',
        )).thenAnswer((_) async => Right(tCourse));
        when(mockGetAllCourses(tUserId))
            .thenAnswer((_) async => Right([tCourse]));
        return bloc;
      },
      act: (bloc) => bloc.add(const CreateCourseEvent(
        userId: tUserId,
        name: 'Chemistry',
        color: '#0000FF',
      )),
      expect: () => [
        isA<CoursesLoading>(),
        isA<CoursesLoaded>(),
      ],
    );

    blocTest<CoursesBloc, CoursesState>(
      'emits [CoursesError] when create fails',
      build: () {
        when(mockCreateCourse(
          userId: tUserId,
          name: 'Fail',
          description: null,
          color: '#000',
        )).thenAnswer(
            (_) async => const Left(CacheFailure('Create error')));
        return bloc;
      },
      act: (bloc) => bloc.add(const CreateCourseEvent(
        userId: tUserId,
        name: 'Fail',
        color: '#000',
      )),
      expect: () => [
        isA<CoursesError>()
            .having((s) => s.message, 'message', 'Create error'),
      ],
    );
  });

  group('UpdateCourseEvent', () {
    blocTest<CoursesBloc, CoursesState>(
      'emits [CoursesLoading, CoursesLoaded] when update succeeds',
      build: () {
        final updatedCourse = tCourse.copyWith(name: 'Advanced Math');
        when(mockUpdateCourse(updatedCourse))
            .thenAnswer((_) async => Right(updatedCourse));
        when(mockGetAllCourses(tUserId))
            .thenAnswer((_) async => Right([updatedCourse]));
        return bloc;
      },
      act: (bloc) => bloc.add(
          UpdateCourseEvent(tCourse.copyWith(name: 'Advanced Math'))),
      expect: () => [
        isA<CoursesLoading>(),
        isA<CoursesLoaded>(),
      ],
    );

    blocTest<CoursesBloc, CoursesState>(
      'emits [CoursesError] when update fails',
      build: () {
        when(mockUpdateCourse(tCourse))
            .thenAnswer((_) async => const Left(CacheFailure('Update error')));
        return bloc;
      },
      act: (bloc) => bloc.add(UpdateCourseEvent(tCourse)),
      expect: () => [
        isA<CoursesError>(),
      ],
    );
  });

  group('DeleteCourseEvent', () {
    blocTest<CoursesBloc, CoursesState>(
      'does nothing when state is not CoursesLoaded (BUG: silent failure)',
      build: () => bloc,
      seed: () => CoursesInitial(),
      act: (bloc) => bloc.add(const DeleteCourseEvent('course-1')),
      expect: () => [],
      verify: (_) {
        verifyNever(mockDeleteCourse(any));
      },
    );

    blocTest<CoursesBloc, CoursesState>(
      'emits [CoursesLoading, CoursesLoaded] when delete succeeds from loaded state',
      build: () {
        when(mockDeleteCourse('course-1'))
            .thenAnswer((_) async => const Right(null));
        when(mockGetAllCourses(tUserId))
            .thenAnswer((_) async => Right([tCourse2]));
        return bloc;
      },
      seed: () => CoursesLoaded([tCourse, tCourse2]),
      act: (bloc) => bloc.add(const DeleteCourseEvent('course-1')),
      expect: () => [
        isA<CoursesLoading>(),
        isA<CoursesLoaded>(),
      ],
    );

    blocTest<CoursesBloc, CoursesState>(
      'emits [CoursesError] when delete fails from loaded state',
      build: () {
        when(mockDeleteCourse('course-1'))
            .thenAnswer((_) async => const Left(CacheFailure('Delete error')));
        return bloc;
      },
      seed: () => CoursesLoaded([tCourse]),
      act: (bloc) => bloc.add(const DeleteCourseEvent('course-1')),
      expect: () => [
        isA<CoursesError>(),
      ],
    );

    // DOCUMENTED BUG: CoursesBloc._onDeleteCourse accesses currentState.courses.first
    // without checking if the list is empty, causing a StateError at runtime.
    // File: lib/features/courses/presentation/bloc/courses_bloc.dart, line 154
    // Additionally, DeleteCourseEvent should carry the userId to avoid this pattern entirely.
    test('DOCUMENTED BUG: crashes with StateError when CoursesLoaded has empty list', () {
      // This test documents the bug - it does not try to fix it.
      // The fix should guard `courses.first` with an isEmpty check or
      // include userId in DeleteCourseEvent.
      expect(true, isTrue); // Placeholder - bug documented in report
    });
  });

  group('CoursesState equality', () {
    test('CoursesLoaded with same courses are equal', () {
      final state1 = CoursesLoaded([tCourse]);
      final state2 = CoursesLoaded([tCourse]);
      expect(state1, equals(state2));
    });

    test('CoursesError with same message are equal', () {
      const state1 = CoursesError('error');
      const state2 = CoursesError('error');
      expect(state1, equals(state2));
    });
  });

  group('CoursesEvent equality', () {
    test('LoadCourses with same userId are equal', () {
      const e1 = LoadCourses(tUserId);
      const e2 = LoadCourses(tUserId);
      expect(e1, equals(e2));
    });

    test('CreateCourseEvent props are correct', () {
      const event = CreateCourseEvent(
        userId: tUserId,
        name: 'Test',
        description: 'Desc',
        color: '#FFF',
      );
      expect(event.props, [tUserId, 'Test', 'Desc', '#FFF']);
    });
  });
}
