import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/course.dart';
import '../repositories/courses_repository.dart';

class GetAllCourses {
  final CoursesRepository repository;

  GetAllCourses(this.repository);

  Future<Either<Failure, List<Course>>> call(String userId) async {
    return await repository.getAllCourses(userId);
  }
}
