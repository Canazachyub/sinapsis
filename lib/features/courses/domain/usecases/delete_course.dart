import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/courses_repository.dart';

class DeleteCourse {
  final CoursesRepository repository;

  DeleteCourse(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteCourse(id);
  }
}
