import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/note.dart';
import '../repositories/notes_repository.dart';

class CreateNote {
  final NotesRepository repository;

  CreateNote(this.repository);

  Future<Either<Failure, Note>> call({
    required String courseId,
    required String userId,
    required String title,
    required String content,
    List<String>? tags,
  }) async {
    return await repository.createNote(
      courseId: courseId,
      userId: userId,
      title: title,
      content: content,
      tags: tags,
    );
  }
}
