import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/course.dart';
import '../../domain/usecases/get_all_courses.dart';
import '../../domain/usecases/create_course.dart';
import '../../domain/usecases/update_course.dart';
import '../../domain/usecases/delete_course.dart';

// Events
abstract class CoursesEvent extends Equatable {
  const CoursesEvent();

  @override
  List<Object?> get props => [];
}

class LoadCourses extends CoursesEvent {
  final String userId;
  const LoadCourses(this.userId);

  @override
  List<Object?> get props => [userId];
}

class CreateCourseEvent extends CoursesEvent {
  final String userId;
  final String name;
  final String? description;
  final String color;

  const CreateCourseEvent({
    required this.userId,
    required this.name,
    this.description,
    required this.color,
  });

  @override
  List<Object?> get props => [userId, name, description, color];
}

class UpdateCourseEvent extends CoursesEvent {
  final Course course;
  const UpdateCourseEvent(this.course);

  @override
  List<Object?> get props => [course];
}

class DeleteCourseEvent extends CoursesEvent {
  final String id;
  const DeleteCourseEvent(this.id);

  @override
  List<Object?> get props => [id];
}

// States
abstract class CoursesState extends Equatable {
  const CoursesState();

  @override
  List<Object> get props => [];
}

class CoursesInitial extends CoursesState {}

class CoursesLoading extends CoursesState {}

class CoursesLoaded extends CoursesState {
  final List<Course> courses;

  const CoursesLoaded(this.courses);

  @override
  List<Object> get props => [courses];
}

class CoursesError extends CoursesState {
  final String message;

  const CoursesError(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class CoursesBloc extends Bloc<CoursesEvent, CoursesState> {
  final GetAllCourses getAllCourses;
  final CreateCourse createCourse;
  final UpdateCourse updateCourse;
  final DeleteCourse deleteCourse;

  CoursesBloc({
    required this.getAllCourses,
    required this.createCourse,
    required this.updateCourse,
    required this.deleteCourse,
  }) : super(CoursesInitial()) {
    on<LoadCourses>(_onLoadCourses);
    on<CreateCourseEvent>(_onCreateCourse);
    on<UpdateCourseEvent>(_onUpdateCourse);
    on<DeleteCourseEvent>(_onDeleteCourse);
  }

  Future<void> _onLoadCourses(
    LoadCourses event,
    Emitter<CoursesState> emit,
  ) async {
    emit(CoursesLoading());
    final result = await getAllCourses(event.userId);
    result.fold(
      (failure) => emit(CoursesError(failure.message)),
      (courses) => emit(CoursesLoaded(courses)),
    );
  }

  Future<void> _onCreateCourse(
    CreateCourseEvent event,
    Emitter<CoursesState> emit,
  ) async {
    final result = await createCourse(
      userId: event.userId,
      name: event.name,
      description: event.description,
      color: event.color,
    );

    result.fold(
      (failure) => emit(CoursesError(failure.message)),
      (_) => add(LoadCourses(event.userId)),
    );
  }

  Future<void> _onUpdateCourse(
    UpdateCourseEvent event,
    Emitter<CoursesState> emit,
  ) async {
    final result = await updateCourse(event.course);

    result.fold(
      (failure) => emit(CoursesError(failure.message)),
      (_) => add(LoadCourses(event.course.userId)),
    );
  }

  Future<void> _onDeleteCourse(
    DeleteCourseEvent event,
    Emitter<CoursesState> emit,
  ) async {
    if (state is CoursesLoaded) {
      final currentState = state as CoursesLoaded;
      final userId = currentState.courses.first.userId;

      final result = await deleteCourse(event.id);

      result.fold(
        (failure) => emit(CoursesError(failure.message)),
        (_) => add(LoadCourses(userId)),
      );
    }
  }
}
