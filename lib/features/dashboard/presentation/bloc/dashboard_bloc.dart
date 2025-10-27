import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/statistics_datasource.dart';

// Events
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboardStats extends DashboardEvent {
  final String userId;

  const LoadDashboardStats(this.userId);

  @override
  List<Object?> get props => [userId];
}

class RefreshDashboardStats extends DashboardEvent {
  final String userId;

  const RefreshDashboardStats(this.userId);

  @override
  List<Object?> get props => [userId];
}

// States
abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardStatistics statistics;

  const DashboardLoaded(this.statistics);

  @override
  List<Object?> get props => [statistics];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

class DashboardStatistics extends Equatable {
  final int totalCourses;
  final int totalNotes;
  final int totalSessions;
  final int totalStudyMinutes;
  final int todayPomodoros;
  final int todayPomodoroMinutes;
  final Map<int, int> weeklyMinutes;
  final int notesNeedingReview;

  const DashboardStatistics({
    required this.totalCourses,
    required this.totalNotes,
    required this.totalSessions,
    required this.totalStudyMinutes,
    required this.todayPomodoros,
    required this.todayPomodoroMinutes,
    required this.weeklyMinutes,
    required this.notesNeedingReview,
  });

  String get totalStudyTime {
    final hours = totalStudyMinutes ~/ 60;
    final minutes = totalStudyMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get todayPomodoroTime {
    final hours = todayPomodoroMinutes ~/ 60;
    final minutes = todayPomodoroMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  List<Object?> get props => [
        totalCourses,
        totalNotes,
        totalSessions,
        totalStudyMinutes,
        todayPomodoros,
        todayPomodoroMinutes,
        weeklyMinutes,
        notesNeedingReview,
      ];
}

// Bloc
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final StatisticsDataSource _statisticsDataSource;

  DashboardBloc(this._statisticsDataSource) : super(DashboardInitial()) {
    on<LoadDashboardStats>(_onLoadDashboardStats);
    on<RefreshDashboardStats>(_onRefreshDashboardStats);
  }

  Future<void> _onLoadDashboardStats(
    LoadDashboardStats event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final stats = await _fetchAllStats(event.userId);
      emit(DashboardLoaded(stats));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> _onRefreshDashboardStats(
    RefreshDashboardStats event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      final stats = await _fetchAllStats(event.userId);
      emit(DashboardLoaded(stats));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  Future<DashboardStatistics> _fetchAllStats(String userId) async {
    final results = await Future.wait([
      _statisticsDataSource.getTotalCoursesByUser(userId),
      _statisticsDataSource.getTotalNotesByUser(userId),
      _statisticsDataSource.getTotalStudySessionsByUser(userId),
      _statisticsDataSource.getTotalStudyTimeMinutes(userId),
      _statisticsDataSource.getTodayPomodorosCount(userId),
      _statisticsDataSource.getTodayPomodoroMinutes(userId),
      _statisticsDataSource.getWeeklyStudyTimeMinutes(userId),
      _statisticsDataSource.getNotesNeedingReviewCount(userId),
    ]);

    return DashboardStatistics(
      totalCourses: results[0] as int,
      totalNotes: results[1] as int,
      totalSessions: results[2] as int,
      totalStudyMinutes: results[3] as int,
      todayPomodoros: results[4] as int,
      todayPomodoroMinutes: results[5] as int,
      weeklyMinutes: results[6] as Map<int, int>,
      notesNeedingReview: results[7] as int,
    );
  }
}
