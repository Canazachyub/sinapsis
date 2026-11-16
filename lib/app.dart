import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'core/theme/app_theme.dart';
import 'core/services/inbox_import_service.dart';
import 'core/services/supabase_sync_helper.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/courses/presentation/bloc/courses_bloc.dart';
import 'features/notes/presentation/bloc/notes_bloc.dart';
import 'features/pomodoro/presentation/bloc/pomodoro_bloc.dart';
import 'features/pomodoro/presentation/widgets/floating_pomodoro_widget.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/theme/presentation/bloc/theme_bloc.dart';
import 'features/sync/presentation/bloc/sync_bloc.dart';
import 'features/theme/presentation/bloc/theme_event.dart';
import 'features/theme/presentation/bloc/theme_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'injection_container.dart';

/// Messenger global para mostrar SnackBars desde fuera de un Scaffold
/// (p. ej. tras navegar al dashboard desde el splash).
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class SinapsisApp extends StatelessWidget {
  const SinapsisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => sl<AuthBloc>()..add(const CheckAuthStatus()),
        ),
        BlocProvider(
          create: (context) => sl<CoursesBloc>(),
        ),
        BlocProvider(
          create: (context) => sl<NotesBloc>(),
        ),
        BlocProvider(
          create: (context) => sl<DashboardBloc>(),
        ),
        BlocProvider(
          create: (context) => PomodoroBloc(
            pomodoroDataSource: sl(),
          ),
          lazy: false, // Mantener activo siempre
        ),
        BlocProvider(
          create: (context) => sl<SyncBloc>(),
        ),
        BlocProvider(
          create: (context) => sl<ThemeBloc>()..add(ThemeLoaded()),
        ),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: 'Sinapsis',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: scaffoldMessengerKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeState.themeMode,
            // Configuración de idioma español
            locale: const Locale('es', 'ES'),
            supportedLocales: const [
              Locale('es', 'ES'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            initialRoute: '/splash',
            routes: {
              '/splash': (context) => const SplashPage(),
              '/login': (context) => const LoginPage(),
              '/register': (context) => const RegisterPage(),
              '/dashboard': (context) => const DashboardPage(),
            },
            builder: (context, child) {
              // Usar Overlay para que los Tooltips funcionen correctamente
              return Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => Stack(
                      children: [
                        child ?? const SizedBox.shrink(),
                        const FloatingPomodoroWidget(),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Página de splash que verifica autenticación
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is Authenticated) {
            final userId = state.user.id;
            context.read<PomodoroBloc>().add(SetUserId(userId));
            context.read<SyncBloc>().add(const SyncAutoStarted());

            // Importar capturas del anotador que esperen en el buzón
            // (~/Documentos/sinapsis/inbox) ANTES del pull de Supabase,
            // para que el sync ya las vea. Nunca lanza.
            final inbox = await sl<InboxImportService>().importarPendientes();

            // Pull initial data de Supabase (notas + cursos)
            sl<SupabaseSyncHelper>().pullAll();

            if (!context.mounted) return;
            if (!inbox.sinPendientes) {
              // Los blocs viven en MultiBlocProvider (por encima del
              // Navigator), así que siguen vivos tras cambiar de ruta.
              context.read<CoursesBloc>().add(LoadCourses(userId));
            }
            Navigator.of(context).pushReplacementNamed('/dashboard');

            if (inbox.importoAlgo || inbox.ficherosError > 0) {
              scaffoldMessengerKey.currentState
                ?..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(inbox.mensaje),
                    duration: const Duration(seconds: 5),
                  ),
                );
            }
          } else if (state is Unauthenticated) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.psychology,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Sinapsis',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
