import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/note.dart';
import '../repositories/notes_repository.dart';

class GetNotesByCourse {
  final NotesRepository repository;

  GetNotesByCourse(this.repository);

  Future<Either<Failure, List<Note>>> call(String courseId) async {
    return await repository.getNotesByCourse(courseId);
  }
}
