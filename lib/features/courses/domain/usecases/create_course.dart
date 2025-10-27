import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/course.dart';
import '../repositories/courses_repository.dart';

class CreateCourse {
  final CoursesRepository repository;

  CreateCourse(this.repository);

  Future<Either<Failure, Course>> call({
    required String userId,
    required String name,
    String? description,
    required String color,
  }) async {
    return await repository.createCourse(
      userId: userId,
      name: name,
      description: description,
      color: color,
    );
  }
}
