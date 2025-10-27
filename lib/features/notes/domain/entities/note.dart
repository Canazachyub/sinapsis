import 'package:equatable/equatable.dart';

/// Entidad de Documento/Nota
/// Representa un documento completo con contenido rico en formato Delta (Quill)
/// que puede contener texto, imágenes, código, y marcadores de oclusión
class Note extends Equatable {
  final String id;
  final String courseId;
  final String userId;
  final String title; // Título del documento
  final String content; // Contenido en formato Delta JSON (flutter_quill)
  final List<String> tags;
  final List<OcclusionMark> occlusionMarks; // Marcadores de texto oculto
  final List<ImageOcclusion> imageOcclusions; // Oclusiones en imágenes
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.courseId,
    required this.userId,
    required this.title,
    required this.content,
    this.tags = const [],
    this.occlusionMarks = const [],
    this.imageOcclusions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Note copyWith({
    String? id,
    String? courseId,
    String? userId,
    String? title,
    String? content,
    List<String>? tags,
    List<OcclusionMark>? occlusionMarks,
    List<ImageOcclusion>? imageOcclusions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      occlusionMarks: occlusionMarks ?? this.occlusionMarks,
      imageOcclusions: imageOcclusions ?? this.imageOcclusions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        courseId,
        userId,
        title,
        content,
        tags,
        occlusionMarks,
        imageOcclusions,
        createdAt,
        updatedAt,
      ];
}

/// Marca de oclusión de texto
/// Define un rango de texto que debe ocultarse en modo estudio
class OcclusionMark extends Equatable {
  final String id;
  final int startIndex; // Índice inicial en el contenido
  final int endIndex; // Índice final en el contenido
  final String? hint; // Pista opcional

  const OcclusionMark({
    required this.id,
    required this.startIndex,
    required this.endIndex,
    this.hint,
  });

  @override
  List<Object?> get props => [id, startIndex, endIndex, hint];
}

/// Oclusión en imagen
/// Define un área rectangular en una imagen que debe ocultarse
class ImageOcclusion extends Equatable {
  final String id;
  final String imageUrl; // URL o path de la imagen
  final double x; // Coordenada X (porcentaje)
  final double y; // Coordenada Y (porcentaje)
  final double width; // Ancho (porcentaje)
  final double height; // Alto (porcentaje)
  final String? label; // Etiqueta de la zona oculta

  const ImageOcclusion({
    required this.id,
    required this.imageUrl,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.label,
  });

  @override
  List<Object?> get props => [id, imageUrl, x, y, width, height, label];
}
