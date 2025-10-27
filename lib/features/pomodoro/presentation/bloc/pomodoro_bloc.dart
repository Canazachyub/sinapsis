import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/pomodoro_session.dart';
import '../../data/datasources/pomodoro_datasource.dart';

part 'pomodoro_event.dart';
part 'pomodoro_state.dart';

class PomodoroBloc extends Bloc<PomodoroEvent, PomodoroBlockState> {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _completedPomodoros = 0;
  final PomodoroConfig _config;
  final PomodoroDataSource? _pomodoroDataSource;
  String? _currentUserId;

  PomodoroBloc({
    PomodoroConfig? config,
    PomodoroDataSource? pomodoroDataSource,
  })  : _config = config ?? const PomodoroConfig(),
        _pomodoroDataSource = pomodoroDataSource,
        super(const PomodoroInitial()) {
    on<StartPomodoro>(_onStartPomodoro);
    on<PausePomodoro>(_onPausePomodoro);
    on<ResumePomodoro>(_onResumePomodoro);
    on<StopPomodoro>(_onStopPomodoro);
    on<SkipToBreak>(_onSkipToBreak);
    on<SkipBreak>(_onSkipBreak);
    on<_TickPomodoro>(_onTickPomodoro);
    on<UpdateConfig>(_onUpdateConfig);
    on<ResetPomodoro>(_onResetPomodoro);
    on<SetUserId>(_onSetUserId);
  }

  void _onSetUserId(SetUserId event, Emitter<PomodoroBlockState> emit) {
    _currentUserId = event.userId;
  }

  void _onStartPomodoro(StartPomodoro event, Emitter<PomodoroBlockState> emit) {
    _cancelTimer();
    _remainingSeconds = _config.workSeconds;

    emit(PomodoroRunning(
      currentState: PomodoroState.working,
      remainingSeconds: _remainingSeconds,
      totalSeconds: _config.workSeconds,
      completedPomodoros: _completedPomodoros,
      courseId: event.courseId,
      noteId: event.noteId,
      startedAt: DateTime.now(),
    ));

    _startTimer();
  }

  void _onPausePomodoro(PausePomodoro event, Emitter<PomodoroBlockState> emit) {
    _cancelTimer();
    final currentState = state;
    if (currentState is PomodoroRunning) {
      emit(PomodoroPaused(
        previousState: currentState.currentState,
        remainingSeconds: _remainingSeconds,
        totalSeconds: currentState.totalSeconds,
        completedPomodoros: _completedPomodoros,
        courseId: currentState.courseId,
        noteId: currentState.noteId,
        startedAt: currentState.startedAt,
      ));
    }
  }

  void _onResumePomodoro(ResumePomodoro event, Emitter<PomodoroBlockState> emit) {
    final currentState = state;
    if (currentState is PomodoroPaused) {
      emit(PomodoroRunning(
        currentState: currentState.previousState,
        remainingSeconds: _remainingSeconds,
        totalSeconds: currentState.totalSeconds,
        completedPomodoros: _completedPomodoros,
        courseId: currentState.courseId,
        noteId: currentState.noteId,
        startedAt: currentState.startedAt,
      ));
      _startTimer();
    }
  }

  void _onStopPomodoro(StopPomodoro event, Emitter<PomodoroBlockState> emit) {
    _cancelTimer();
    _remainingSeconds = 0;
    _completedPomodoros = 0;
    emit(const PomodoroInitial());
  }

  void _onSkipToBreak(SkipToBreak event, Emitter<PomodoroBlockState> emit) {
    _cancelTimer();
    _completedPomodoros++;

    // Determinar si es descanso largo o corto
    final isLongBreak = _completedPomodoros % _config.sessionsUntilLongBreak == 0;
    _remainingSeconds = isLongBreak ? _config.longBreakSeconds : _config.breakSeconds;

    emit(PomodoroRunning(
      currentState: PomodoroState.breakTime,
      remainingSeconds: _remainingSeconds,
      totalSeconds: _remainingSeconds,
      completedPomodoros: _completedPomodoros,
      courseId: null,
      noteId: null,
      startedAt: DateTime.now(),
      isLongBreak: isLongBreak,
    ));

    if (_config.autoStartBreaks) {
      _startTimer();
    }
  }

  void _onSkipBreak(SkipBreak event, Emitter<PomodoroBlockState> emit) {
    _cancelTimer();
    _remainingSeconds = _config.workSeconds;

    emit(PomodoroRunning(
      currentState: PomodoroState.working,
      remainingSeconds: _remainingSeconds,
      totalSeconds: _config.workSeconds,
      completedPomodoros: _completedPomodoros,
      courseId: event.courseId,
      noteId: event.noteId,
      startedAt: DateTime.now(),
    ));

    if (_config.autoStartPomodoros) {
      _startTimer();
    }
  }

  void _onTickPomodoro(_TickPomodoro event, Emitter<PomodoroBlockState> emit) async {
    _remainingSeconds--;

    if (_remainingSeconds <= 0) {
      _cancelTimer();

      final currentState = state;
      if (currentState is PomodoroRunning) {
        if (currentState.currentState == PomodoroState.working) {
          // Guardar la sesión en la base de datos
          if (_pomodoroDataSource != null && _currentUserId != null) {
            try {
              await _pomodoroDataSource!.savePomodoroSession(
                userId: _currentUserId!,
                courseId: currentState.courseId,
                noteId: currentState.noteId,
                workDuration: _config.workSeconds,
                breakDuration: _config.breakSeconds,
                startedAt: currentState.startedAt,
                wasInterrupted: false,
              );
            } catch (e) {
              // Log error but don't interrupt the flow
              print('Error saving pomodoro session: $e');
            }
          }

          // Terminar periodo de trabajo, iniciar descanso
          emit(PomodoroCompleted(
            completedPomodoros: _completedPomodoros + 1,
            courseId: currentState.courseId,
            noteId: currentState.noteId,
          ));
        } else {
          // Terminar descanso
          emit(BreakCompleted(
            completedPomodoros: _completedPomodoros,
          ));
        }
      }
    } else {
      final currentState = state;
      if (currentState is PomodoroRunning) {
        emit(PomodoroRunning(
          currentState: currentState.currentState,
          remainingSeconds: _remainingSeconds,
          totalSeconds: currentState.totalSeconds,
          completedPomodoros: _completedPomodoros,
          courseId: currentState.courseId,
          noteId: currentState.noteId,
          startedAt: currentState.startedAt,
          isLongBreak: currentState.isLongBreak,
        ));
      }
    }
  }

  void _onUpdateConfig(UpdateConfig event, Emitter<PomodoroBlockState> emit) {
    // Actualizar configuración (solo si no hay sesión activa)
    if (state is PomodoroInitial) {
      // La configuración se actualiza pero necesitaríamos crear un nuevo bloc o manejar config como parte del state
      // Por ahora simplemente re-emitimos el estado inicial
      emit(const PomodoroInitial());
    }
  }

  void _onResetPomodoro(ResetPomodoro event, Emitter<PomodoroBlockState> emit) {
    _cancelTimer();
    _remainingSeconds = 0;
    _completedPomodoros = 0;
    emit(const PomodoroInitial());
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      add(const _TickPomodoro());
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() {
    _cancelTimer();
    return super.close();
  }
}
