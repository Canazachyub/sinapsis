import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/courses/presentation/bloc/courses_bloc.dart';
import 'features/notes/presentation/bloc/notes_bloc.dart';
import 'features/pomodoro/presentation/bloc/pomodoro_bloc.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'injection_container.dart';

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
      ],
      child: MaterialApp(
        title: 'Sinapsis',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashPage(),
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),
          '/dashboard': (context) => const DashboardPage(),
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
        listener: (context, state) {
          if (state is Authenticated) {
            // Establecer userId en PomodoroBloc
            context.read<PomodoroBloc>().add(SetUserId(state.user.id));
            Navigator.of(context).pushReplacementNamed('/dashboard');
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
