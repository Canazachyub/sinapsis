import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/course.dart';

part 'course_model.freezed.dart';
part 'course_model.g.dart';

@freezed
class CourseModel with _$CourseModel {
  const CourseModel._();

  const factory CourseModel({
    required String id,
    required String userId,
    required String name,
    String? description,
    required String color,
    @Default(false) bool isFavorite,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _CourseModel;

  factory CourseModel.fromJson(Map<String, dynamic> json) =>
      _$CourseModelFromJson(json);

  factory CourseModel.fromEntity(Course course) {
    return CourseModel(
      id: course.id,
      userId: course.userId,
      name: course.name,
      description: course.description,
      color: course.color,
      isFavorite: course.isFavorite,
      createdAt: course.createdAt,
      updatedAt: course.updatedAt,
    );
  }

  Course toEntity() {
    return Course(
      id: id,
      userId: userId,
      name: name,
      description: description,
      color: color,
      isFavorite: isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
