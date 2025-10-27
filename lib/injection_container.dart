import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Core
import 'core/network/network_info.dart';
import 'core/network/dio_client.dart';
import 'core/database/database.dart';

// Auth
import 'features/auth/data/datasources/auth_local_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource_mock.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/register_usecase.dart';
import 'features/auth/domain/usecases/logout_usecase.dart';
import 'features/auth/domain/usecases/get_current_user_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

// Courses
import 'features/courses/data/datasources/courses_local_datasource.dart';
import 'features/courses/data/repositories/courses_repository_impl.dart';
import 'features/courses/domain/repositories/courses_repository.dart';
import 'features/courses/domain/usecases/get_all_courses.dart';
import 'features/courses/domain/usecases/create_course.dart';
import 'features/courses/domain/usecases/update_course.dart';
import 'features/courses/domain/usecases/delete_course.dart';
import 'features/courses/presentation/bloc/courses_bloc.dart';

// Notes
import 'features/notes/data/datasources/notes_local_datasource.dart';
import 'features/notes/data/datasources/notes_srs_datasource.dart';
import 'features/notes/data/repositories/notes_repository_impl.dart';
import 'features/notes/domain/repositories/notes_repository.dart';
import 'features/notes/domain/usecases/get_notes_by_course.dart';
import 'features/notes/domain/usecases/create_note.dart';
import 'features/notes/domain/usecases/update_note.dart';
import 'features/notes/domain/usecases/delete_note.dart';
import 'features/notes/presentation/bloc/notes_bloc.dart';

// Dashboard
import 'features/dashboard/data/statistics_datasource.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';

// Pomodoro
import 'features/pomodoro/data/datasources/pomodoro_datasource.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ===== Features =====

  // Auth - Bloc
  sl.registerFactory(
    () => AuthBloc(
      loginUseCase: sl(),
      registerUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
    ),
  );

  // Courses - Bloc
  sl.registerFactory(
    () => CoursesBloc(
      getAllCourses: sl(),
      createCourse: sl(),
      updateCourse: sl(),
      deleteCourse: sl(),
    ),
  );

  // Notes - Bloc
  sl.registerFactory(
    () => NotesBloc(
      getNotesByCourse: sl(),
      createNote: sl(),
      updateNote: sl(),
      deleteNote: sl(),
    ),
  );

  // Dashboard - Bloc
  sl.registerFactory(
    () => DashboardBloc(sl()),
  );

  // Auth - Use Cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));

  // Auth - Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Auth - Data Sources
  // Detectar modo demo
  final isDemoMode = dotenv.env['APP_ENV'] == 'demo' ||
                     dotenv.env['SUPABASE_URL']?.contains('tu-proyecto') == true ||
                     dotenv.env['SUPABASE_URL']?.contains('placeholder') == true;

  if (isDemoMode) {
    // Modo DEMO: usar mock local sin Supabase
    sl.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceMockImpl(prefs: sl()),
    );
  } else {
    // Modo PRODUCCIÓN: usar Supabase
    sl.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(client: sl()),
    );
  }

  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  );

  // Courses - Use Cases
  sl.registerLazySingleton(() => GetAllCourses(sl()));
  sl.registerLazySingleton(() => CreateCourse(sl()));
  sl.registerLazySingleton(() => UpdateCourse(sl()));
  sl.registerLazySingleton(() => DeleteCourse(sl()));

  // Courses - Repository
  sl.registerLazySingleton<CoursesRepository>(
    () => CoursesRepositoryImpl(localDataSource: sl()),
  );

  // Courses - Data Sources
  sl.registerLazySingleton<CoursesLocalDataSource>(
    () => CoursesLocalDataSourceImpl(prefs: sl()),
  );

  // Notes - Use Cases
  sl.registerLazySingleton(() => GetNotesByCourse(sl()));
  sl.registerLazySingleton(() => CreateNote(sl()));
  sl.registerLazySingleton(() => UpdateNote(sl()));
  sl.registerLazySingleton(() => DeleteNote(sl()));

  // Notes - Repository
  sl.registerLazySingleton<NotesRepository>(
    () => NotesRepositoryImpl(localDataSource: sl()),
  );

  // Notes - Data Sources
  sl.registerLazySingleton<NotesLocalDataSource>(
    () => NotesLocalDataSourceImpl(prefs: sl()),
  );

  sl.registerLazySingleton<NotesSRSDataSource>(
    () => NotesSRSDataSource(sl()),
  );

  // Dashboard - Data Sources
  sl.registerLazySingleton<StatisticsDataSource>(
    () => StatisticsDataSource(sl(), sl()),
  );

  // Pomodoro - Data Sources
  sl.registerLazySingleton<PomodoroDataSource>(
    () => PomodoroDataSource(sl()),
  );

  // ===== Core =====

  // Network
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
  sl.registerLazySingleton(() => DioClient());

  // Database
  sl.registerLazySingleton(() => AppDatabase());

  // ===== External =====

  // Supabase
  try {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty &&
        !supabaseUrl.contains('tu-proyecto') &&
        !supabaseUrl.contains('placeholder')) {
      final supabase = await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );
      sl.registerLazySingleton(() => supabase.client);
    } else {
      // Modo demo sin Supabase - crea un cliente mock
      final supabase = await Supabase.initialize(
        url: 'https://demo.supabase.co',
        anonKey: 'demo-key',
      );
      sl.registerLazySingleton(() => supabase.client);
    }
  } catch (e) {
    // Si falla, usa valores demo
    final supabase = await Supabase.initialize(
      url: 'https://demo.supabase.co',
      anonKey: 'demo-key',
    );
    sl.registerLazySingleton(() => supabase.client);
  }

  // SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
}
