import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import '../../data/theme_preferences.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final ThemePreferences _preferences;

  ThemeBloc(this._preferences) : super(const ThemeState()) {
    on<ThemeLoaded>(_onThemeLoaded);
    on<ThemeChanged>(_onThemeChanged);
  }

  Future<void> _onThemeLoaded(
    ThemeLoaded event,
    Emitter<ThemeState> emit,
  ) async {
    final savedTheme = await _preferences.getThemeMode();
    emit(state.copyWith(themeMode: savedTheme));
  }

  Future<void> _onThemeChanged(
    ThemeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    emit(state.copyWith(themeMode: event.mode));
    await _preferences.setThemeMode(event.mode);
  }
}
