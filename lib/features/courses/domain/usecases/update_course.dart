import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/course.dart';
import '../repositories/courses_repository.dart';

class UpdateCourse {
  final CoursesRepository repository;

  UpdateCourse(this.repository);

  Future<Either<Failure, Course>> call(Course course) async {
    return await repository.updateCourse(course);
  }
}
