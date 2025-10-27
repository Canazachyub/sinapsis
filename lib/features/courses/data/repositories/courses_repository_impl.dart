import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/course.dart';
import '../../domain/repositories/courses_repository.dart';
import '../datasources/courses_local_datasource.dart';
import '../models/course_model.dart';

class CoursesRepositoryImpl implements CoursesRepository {
  final CoursesLocalDataSource localDataSource;

  CoursesRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<Course>>> getAllCourses(String userId) async {
    try {
      final courses = await localDataSource.getAllCourses(userId);
      return Right(courses.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Course>> getCourse(String id) async {
    try {
      final course = await localDataSource.getCourse(id);
      return Right(course.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Course>> createCourse({
    required String userId,
    required String name,
    String? description,
    required String color,
  }) async {
    try {
      final now = DateTime.now();
      final course = CourseModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        name: name,
        description: description,
        color: color,
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
      );

      await localDataSource.saveCourse(course);
      return Right(course.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Course>> updateCourse(Course course) async {
    try {
      final model = CourseModel.fromEntity(course).copyWith(
        updatedAt: DateTime.now(),
      );
      await localDataSource.updateCourse(model);
      return Right(model.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCourse(String id) async {
    try {
      await localDataSource.deleteCourse(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Course>> toggleFavorite(String id) async {
    try {
      final course = await localDataSource.getCourse(id);
      final updated = course.copyWith(
        isFavorite: !course.isFavorite,
        updatedAt: DateTime.now(),
      );
      await localDataSource.updateCourse(updated);
      return Right(updated.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Course>>> searchCourses(
      String userId, String query) async {
    try {
      final courses = await localDataSource.searchCourses(userId, query);
      return Right(courses.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Course>>> getFavoriteCourses(
      String userId) async {
    try {
      final courses = await localDataSource.getFavoriteCourses(userId);
      return Right(courses.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
