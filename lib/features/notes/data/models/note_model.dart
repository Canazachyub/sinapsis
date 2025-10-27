import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/note.dart';

part 'note_model.freezed.dart';
part 'note_model.g.dart';

@freezed
class OcclusionMarkModel with _$OcclusionMarkModel {
  const OcclusionMarkModel._();

  const factory OcclusionMarkModel({
    required String id,
    required int startIndex,
    required int endIndex,
    String? hint,
  }) = _OcclusionMarkModel;

  factory OcclusionMarkModel.fromJson(Map<String, dynamic> json) =>
      _$OcclusionMarkModelFromJson(json);

  factory OcclusionMarkModel.fromEntity(OcclusionMark mark) {
    return OcclusionMarkModel(
      id: mark.id,
      startIndex: mark.startIndex,
      endIndex: mark.endIndex,
      hint: mark.hint,
    );
  }

  OcclusionMark toEntity() {
    return OcclusionMark(
      id: id,
      startIndex: startIndex,
      endIndex: endIndex,
      hint: hint,
    );
  }
}

@freezed
class ImageOcclusionModel with _$ImageOcclusionModel {
  const ImageOcclusionModel._();

  const factory ImageOcclusionModel({
    required String id,
    required String imageUrl,
    required double x,
    required double y,
    required double width,
    required double height,
    String? label,
  }) = _ImageOcclusionModel;

  factory ImageOcclusionModel.fromJson(Map<String, dynamic> json) =>
      _$ImageOcclusionModelFromJson(json);

  factory ImageOcclusionModel.fromEntity(ImageOcclusion occlusion) {
    return ImageOcclusionModel(
      id: occlusion.id,
      imageUrl: occlusion.imageUrl,
      x: occlusion.x,
      y: occlusion.y,
      width: occlusion.width,
      height: occlusion.height,
      label: occlusion.label,
    );
  }

  ImageOcclusion toEntity() {
    return ImageOcclusion(
      id: id,
      imageUrl: imageUrl,
      x: x,
      y: y,
      width: width,
      height: height,
      label: label,
    );
  }
}

@freezed
class NoteModel with _$NoteModel {
  const NoteModel._();

  const factory NoteModel({
    required String id,
    required String courseId,
    required String userId,
    required String title,
    required String content, // Delta JSON de Quill
    @Default([]) List<String> tags,
    @Default([]) List<OcclusionMarkModel> occlusionMarks,
    @Default([]) List<ImageOcclusionModel> imageOcclusions,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _NoteModel;

  factory NoteModel.fromJson(Map<String, dynamic> json) =>
      _$NoteModelFromJson(json);

  factory NoteModel.fromEntity(Note note) {
    return NoteModel(
      id: note.id,
      courseId: note.courseId,
      userId: note.userId,
      title: note.title,
      content: note.content,
      tags: note.tags,
      occlusionMarks: note.occlusionMarks
          .map((m) => OcclusionMarkModel.fromEntity(m))
          .toList(),
      imageOcclusions: note.imageOcclusions
          .map((o) => ImageOcclusionModel.fromEntity(o))
          .toList(),
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    );
  }

  Note toEntity() {
    return Note(
      id: id,
      courseId: courseId,
      userId: userId,
      title: title,
      content: content,
      tags: tags,
      occlusionMarks: occlusionMarks.map((m) => m.toEntity()).toList(),
      imageOcclusions: imageOcclusions.map((o) => o.toEntity()).toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
