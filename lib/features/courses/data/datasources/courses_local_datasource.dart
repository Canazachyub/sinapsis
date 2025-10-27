import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/course_model.dart';

/// DataSource local para cursos
abstract class CoursesLocalDataSource {
  Future<List<CourseModel>> getAllCourses(String userId);
  Future<CourseModel> getCourse(String id);
  Future<void> saveCourse(CourseModel course);
  Future<void> updateCourse(CourseModel course);
  Future<void> deleteCourse(String id);
  Future<List<CourseModel>> searchCourses(String userId, String query);
  Future<List<CourseModel>> getFavoriteCourses(String userId);
}

/// Implementación con SharedPreferences
class CoursesLocalDataSourceImpl implements CoursesLocalDataSource {
  final SharedPreferences prefs;
  static const String _coursesKey = 'COURSES_DATA';

  CoursesLocalDataSourceImpl({required this.prefs});

  // Obtener todos los cursos del almacenamiento
  Map<String, dynamic> _getCourses() {
    final coursesJson = prefs.getString(_coursesKey);
    if (coursesJson == null) return {};
    return json.decode(coursesJson) as Map<String, dynamic>;
  }

  // Guardar cursos al almacenamiento
  Future<void> _saveCourses(Map<String, dynamic> courses) async {
    await prefs.setString(_coursesKey, json.encode(courses));
  }

  @override
  Future<List<CourseModel>> getAllCourses(String userId) async {
    try {
      final courses = _getCourses();
      final userCourses = courses.values
          .map((json) => CourseModel.fromJson(json as Map<String, dynamic>))
          .where((course) => course.userId == userId)
          .toList();

      // Ordenar por fecha de actualización (más reciente primero)
      userCourses.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return userCourses;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<CourseModel> getCourse(String id) async {
    try {
      final courses = _getCourses();
      final courseJson = courses[id];
      if (courseJson == null) {
        throw const CacheException('Curso no encontrado');
      }
      return CourseModel.fromJson(courseJson as Map<String, dynamic>);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> saveCourse(CourseModel course) async {
    try {
      final courses = _getCourses();
      courses[course.id] = course.toJson();
      await _saveCourses(courses);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> updateCourse(CourseModel course) async {
    try {
      final courses = _getCourses();
      if (!courses.containsKey(course.id)) {
        throw const CacheException('Curso no encontrado');
      }
      courses[course.id] = course.toJson();
      await _saveCourses(courses);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> deleteCourse(String id) async {
    try {
      final courses = _getCourses();
      courses.remove(id);
      await _saveCourses(courses);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<List<CourseModel>> searchCourses(String userId, String query) async {
    try {
      final allCourses = await getAllCourses(userId);
      final lowerQuery = query.toLowerCase();

      return allCourses.where((course) {
        final nameMatch = course.name.toLowerCase().contains(lowerQuery);
        final descMatch = course.description?.toLowerCase().contains(lowerQuery) ?? false;
        return nameMatch || descMatch;
      }).toList();
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<List<CourseModel>> getFavoriteCourses(String userId) async {
    try {
      final allCourses = await getAllCourses(userId);
      return allCourses.where((course) => course.isFavorite).toList();
    } catch (e) {
      throw CacheException(e.toString());
    }
  }
}
