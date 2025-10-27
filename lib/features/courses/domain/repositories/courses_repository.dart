import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/course.dart';

abstract class CoursesRepository {
  Future<Either<Failure, List<Course>>> getAllCourses(String userId);
  Future<Either<Failure, Course>> getCourse(String id);
  Future<Either<Failure, Course>> createCourse({
    required String userId,
    required String name,
    String? description,
    required String color,
  });
  Future<Either<Failure, Course>> updateCourse(Course course);
  Future<Either<Failure, void>> deleteCourse(String id);
  Future<Either<Failure, Course>> toggleFavorite(String id);
  Future<Either<Failure, List<Course>>> searchCourses(String userId, String query);
  Future<Either<Failure, List<Course>>> getFavoriteCourses(String userId);
}
