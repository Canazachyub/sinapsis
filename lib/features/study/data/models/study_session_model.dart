import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/study_session.dart';

part 'study_session_model.freezed.dart';
part 'study_session_model.g.dart';

@freezed
class StudyRecordModel with _$StudyRecordModel {
  const StudyRecordModel._();

  const factory StudyRecordModel({
    required String noteId,
    required Difficulty difficulty,
    required DateTime timestamp,
  }) = _StudyRecordModel;

  factory StudyRecordModel.fromJson(Map<String, dynamic> json) =>
      _$StudyRecordModelFromJson(json);

  factory StudyRecordModel.fromEntity(StudyRecord record) {
    return StudyRecordModel(
      noteId: record.noteId,
      difficulty: record.difficulty,
      timestamp: record.timestamp,
    );
  }

  StudyRecord toEntity() {
    return StudyRecord(
      noteId: noteId,
      difficulty: difficulty,
      timestamp: timestamp,
    );
  }
}

@freezed
class StudySessionModel with _$StudySessionModel {
  const StudySessionModel._();

  const factory StudySessionModel({
    required String id,
    required String userId,
    required String courseId,
    required DateTime startTime,
    DateTime? endTime,
    @Default([]) List<StudyRecordModel> records,
    required int totalCards,
    @Default(0) int reviewedCards,
  }) = _StudySessionModel;

  factory StudySessionModel.fromJson(Map<String, dynamic> json) =>
      _$StudySessionModelFromJson(json);

  factory StudySessionModel.fromEntity(StudySession session) {
    return StudySessionModel(
      id: session.id,
      userId: session.userId,
      courseId: session.courseId,
      startTime: session.startTime,
      endTime: session.endTime,
      records: session.records
          .map((r) => StudyRecordModel.fromEntity(r))
          .toList(),
      totalCards: session.totalCards,
      reviewedCards: session.reviewedCards,
    );
  }

  StudySession toEntity() {
    return StudySession(
      id: id,
      userId: userId,
      courseId: courseId,
      startTime: startTime,
      endTime: endTime,
      records: records.map((r) => r.toEntity()).toList(),
      totalCards: totalCards,
      reviewedCards: reviewedCards,
    );
  }
}
