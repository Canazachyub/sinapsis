import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/note.dart';

part 'note_model.freezed.dart';
part 'note_model.g.dart';

@freezed
sealed class OcclusionMarkModel with _$OcclusionMarkModel {
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
sealed class ImageOcclusionModel with _$ImageOcclusionModel {
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
sealed class NoteModel with _$NoteModel {
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
    // ---- Repaso espaciado (SM-2). Opcionales: las notas antiguas sin estos
    // campos cargan como "nuevas". Solo se guardan en local (NOTES_DATA);
    // no viajan a Supabase (ver docs/SRS.md).
    @Default(2.5) double srsEase,
    @Default(0) int srsInterval, // días
    @Default(0) int srsRepetitions,
    DateTime? srsDue, // null = nueva
    @Default(0) int srsLapses,
    DateTime? srsLastReview,
  }) = _NoteModel;

  /// Tolerante: ignora campos SRS ausentes o con tipos incorrectos.
  factory NoteModel.fromJson(Map<String, dynamic> json) =>
      _$NoteModelFromJson(limpiarCamposSrs(json));

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
      srsEase: note.srs.ease,
      srsInterval: note.srs.intervalo,
      srsRepetitions: note.srs.repeticiones,
      srsDue: note.srs.vence,
      srsLapses: note.srs.lapsos,
      srsLastReview: note.srs.ultimoRepaso,
    );
  }

  /// Estado SRS de esta nota.
  EstadoSrs get srs => EstadoSrs(
        ease: srsEase,
        intervalo: srsInterval,
        repeticiones: srsRepetitions,
        vence: srsDue,
        lapsos: srsLapses,
        ultimoRepaso: srsLastReview,
      );

  /// Copia con otro estado SRS (permite volver a `null` las fechas).
  NoteModel conSrs(EstadoSrs e) => copyWith(
        srsEase: e.ease,
        srsInterval: e.intervalo,
        srsRepetitions: e.repeticiones,
        srsDue: e.vence,
        srsLapses: e.lapsos,
        srsLastReview: e.ultimoRepaso,
      );

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
      srs: srs,
    );
  }
}

/// Elimina del JSON los campos SRS con tipos inválidos para que
/// `fromJson` use los valores por defecto en vez de lanzar.
Map<String, dynamic> limpiarCamposSrs(Map<String, dynamic> json) {
  const numericos = ['srsEase', 'srsInterval', 'srsRepetitions', 'srsLapses'];
  const fechas = ['srsDue', 'srsLastReview'];
  var limpio = json;
  void quitar(String k) {
    if (identical(limpio, json)) limpio = Map<String, dynamic>.from(json);
    limpio.remove(k);
  }

  for (final k in numericos) {
    final v = json[k];
    if (v != null && v is! num) quitar(k);
  }
  for (final k in fechas) {
    final v = json[k];
    if (v != null && (v is! String || DateTime.tryParse(v) == null)) quitar(k);
  }
  // Los enteros podrían llegar como double (p. ej. 6.0).
  for (final k in ['srsInterval', 'srsRepetitions', 'srsLapses']) {
    final v = limpio[k];
    if (v is double) {
      if (identical(limpio, json)) limpio = Map<String, dynamic>.from(json);
      limpio[k] = v.round();
    }
  }
  return limpio;
}
