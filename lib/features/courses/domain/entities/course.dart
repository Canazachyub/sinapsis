import 'package:equatable/equatable.dart';

/// Entidad de Curso
class Course extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String color;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Course({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.color,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Course copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? color,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        description,
        color,
        isFavorite,
        createdAt,
        updatedAt,
      ];
}
