import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/note.dart';
import '../../domain/usecases/get_notes_by_course.dart';
import '../../domain/usecases/create_note.dart';
import '../../domain/usecases/update_note.dart';
import '../../domain/usecases/delete_note.dart';

// Events
abstract class NotesEvent extends Equatable {
  const NotesEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotes extends NotesEvent {
  final String courseId;
  const LoadNotes(this.courseId);

  @override
  List<Object?> get props => [courseId];
}

class CreateNoteEvent extends NotesEvent {
  final String courseId;
  final String userId;
  final String title;
  final String content; // Delta JSON de Quill
  final List<String> tags;

  const CreateNoteEvent({
    required this.courseId,
    required this.userId,
    required this.title,
    required this.content,
    this.tags = const [],
  });

  @override
  List<Object?> get props => [courseId, userId, title, content, tags];
}

class UpdateNoteEvent extends NotesEvent {
  final Note note;
  const UpdateNoteEvent(this.note);

  @override
  List<Object?> get props => [note];
}

class DeleteNoteEvent extends NotesEvent {
  final String id;
  final String courseId;
  const DeleteNoteEvent(this.id, this.courseId);

  @override
  List<Object?> get props => [id, courseId];
}

// States
abstract class NotesState extends Equatable {
  const NotesState();

  @override
  List<Object> get props => [];
}

class NotesInitial extends NotesState {}

class NotesLoading extends NotesState {}

class NotesLoaded extends NotesState {
  final List<Note> notes;
  final String courseId;

  const NotesLoaded(this.notes, this.courseId);

  @override
  List<Object> get props => [notes, courseId];
}

class NotesError extends NotesState {
  final String message;

  const NotesError(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class NotesBloc extends Bloc<NotesEvent, NotesState> {
  final GetNotesByCourse getNotesByCourse;
  final CreateNote createNote;
  final UpdateNote updateNote;
  final DeleteNote deleteNote;

  NotesBloc({
    required this.getNotesByCourse,
    required this.createNote,
    required this.updateNote,
    required this.deleteNote,
  }) : super(NotesInitial()) {
    on<LoadNotes>(_onLoadNotes);
    on<CreateNoteEvent>(_onCreateNote);
    on<UpdateNoteEvent>(_onUpdateNote);
    on<DeleteNoteEvent>(_onDeleteNote);
  }

  Future<void> _onLoadNotes(
    LoadNotes event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoading());
    final result = await getNotesByCourse(event.courseId);
    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (notes) => emit(NotesLoaded(notes, event.courseId)),
    );
  }

  Future<void> _onCreateNote(
    CreateNoteEvent event,
    Emitter<NotesState> emit,
  ) async {
    final result = await createNote(
      courseId: event.courseId,
      userId: event.userId,
      title: event.title,
      content: event.content,
      tags: event.tags,
    );

    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (_) => add(LoadNotes(event.courseId)),
    );
  }

  Future<void> _onUpdateNote(
    UpdateNoteEvent event,
    Emitter<NotesState> emit,
  ) async {
    final result = await updateNote(event.note);

    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (_) => add(LoadNotes(event.note.courseId)),
    );
  }

  Future<void> _onDeleteNote(
    DeleteNoteEvent event,
    Emitter<NotesState> emit,
  ) async {
    final result = await deleteNote(event.id);

    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (_) => add(LoadNotes(event.courseId)),
    );
  }
}
