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
  final String userId;
  final String courseId;
  const LoadNotes(this.userId, this.courseId);

  @override
  List<Object?> get props => [userId, courseId];
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
  final String userId;
  final String courseId;
  const DeleteNoteEvent(this.id, this.userId, this.courseId);

  @override
  List<Object?> get props => [id, userId, courseId];
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

class NotesSaving extends NotesState {
  final List<Note> notes;
  final String courseId;

  const NotesSaving(this.notes, this.courseId);

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
    final result = await getNotesByCourse(event.userId, event.courseId);
    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (notes) => emit(NotesLoaded(notes, event.courseId)),
    );
  }

  Future<void> _onCreateNote(
    CreateNoteEvent event,
    Emitter<NotesState> emit,
  ) async {
    if (event.title.trim().isEmpty) {
      emit(const NotesError('El título no puede estar vacío'));
      return;
    }
    if (event.courseId.trim().isEmpty || event.userId.trim().isEmpty) {
      emit(const NotesError('Datos de curso o usuario inválidos'));
      return;
    }

    _emitSaving(emit);

    final result = await createNote(
      courseId: event.courseId,
      userId: event.userId,
      title: event.title,
      content: event.content,
      tags: event.tags,
    );

    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (_) => add(LoadNotes(event.userId, event.courseId)),
    );
  }

  Future<void> _onUpdateNote(
    UpdateNoteEvent event,
    Emitter<NotesState> emit,
  ) async {
    if (event.note.title.trim().isEmpty) {
      emit(const NotesError('El título no puede estar vacío'));
      return;
    }

    _emitSaving(emit);

    final result = await updateNote(event.note);

    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (_) => add(LoadNotes(event.note.userId, event.note.courseId)),
    );
  }

  Future<void> _onDeleteNote(
    DeleteNoteEvent event,
    Emitter<NotesState> emit,
  ) async {
    if (event.id.trim().isEmpty) {
      emit(const NotesError('ID de nota inválido'));
      return;
    }

    _emitSaving(emit);

    final result = await deleteNote(event.id);

    result.fold(
      (failure) => emit(NotesError(failure.message)),
      (_) => add(LoadNotes(event.userId, event.courseId)),
    );
  }

  void _emitSaving(Emitter<NotesState> emit) {
    if (state is NotesLoaded) {
      final loaded = state as NotesLoaded;
      emit(NotesSaving(loaded.notes, loaded.courseId));
    }
  }
}
