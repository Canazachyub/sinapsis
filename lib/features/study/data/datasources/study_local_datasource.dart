import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/study_session_model.dart';

abstract class StudyLocalDataSource {
  Future<List<StudySessionModel>> getAllSessions(String userId);
  Future<List<StudySessionModel>> getSessionsByCourse(String courseId);
  Future<StudySessionModel> getSession(String id);
  Future<void> saveSession(StudySessionModel session);
  Future<void> updateSession(StudySessionModel session);
  Future<void> deleteSession(String id);
}

class StudyLocalDataSourceImpl implements StudyLocalDataSource {
  final SharedPreferences prefs;
  static const String _sessionsKey = 'STUDY_SESSIONS_DATA';

  StudyLocalDataSourceImpl({required this.prefs});

  Map<String, dynamic> _getSessions() {
    final sessionsJson = prefs.getString(_sessionsKey);
    if (sessionsJson == null) return {};
    return json.decode(sessionsJson) as Map<String, dynamic>;
  }

  Future<void> _saveSessions(Map<String, dynamic> sessions) async {
    await prefs.setString(_sessionsKey, json.encode(sessions));
  }

  @override
  Future<List<StudySessionModel>> getAllSessions(String userId) async {
    try {
      final sessions = _getSessions();
      final userSessions = sessions.values
          .map((json) => StudySessionModel.fromJson(json as Map<String, dynamic>))
          .where((session) => session.userId == userId)
          .toList();

      userSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      return userSessions;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<List<StudySessionModel>> getSessionsByCourse(String courseId) async {
    try {
      final sessions = _getSessions();
      final courseSessions = sessions.values
          .map((json) => StudySessionModel.fromJson(json as Map<String, dynamic>))
          .where((session) => session.courseId == courseId)
          .toList();

      courseSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      return courseSessions;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<StudySessionModel> getSession(String id) async {
    try {
      final sessions = _getSessions();
      final sessionJson = sessions[id];
      if (sessionJson == null) {
        throw const CacheException('Sesión no encontrada');
      }
      return StudySessionModel.fromJson(sessionJson as Map<String, dynamic>);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> saveSession(StudySessionModel session) async {
    try {
      final sessions = _getSessions();
      sessions[session.id] = session.toJson();
      await _saveSessions(sessions);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> updateSession(StudySessionModel session) async {
    try {
      final sessions = _getSessions();
      if (!sessions.containsKey(session.id)) {
        throw const CacheException('Sesión no encontrada');
      }
      sessions[session.id] = session.toJson();
      await _saveSessions(sessions);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    try {
      final sessions = _getSessions();
      sessions.remove(id);
      await _saveSessions(sessions);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }
}
