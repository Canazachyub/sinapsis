import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../courses/presentation/pages/courses_page.dart';
import '../../../pomodoro/presentation/widgets/pomodoro_timer_widget.dart';
import '../../../pomodoro/presentation/widgets/floating_pomodoro_widget.dart';
import '../../../notes/presentation/pages/review_page.dart';
import '../bloc/dashboard_bloc.dart';
import 'srs_stats_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const CoursesPage(),
    const _StatsPage(),
    const _ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            _pages[_selectedIndex],
            const FloatingPomodoroWidget(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Cursos',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Estadísticas',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsPage extends StatefulWidget {
  const _StatsPage();

  @override
  State<_StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<_StatsPage> {
  @override
  void initState() {
    super.initState();
    // Cargar estadísticas al iniciar
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<DashboardBloc>().add(LoadDashboardStats(authState.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard de Estudio'),
          actions: [
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar',
                  onPressed: () {
                    if (authState is Authenticated) {
                      context.read<DashboardBloc>().add(RefreshDashboardStats(authState.user.id));
                    }
                  },
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state is DashboardLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is DashboardError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${state.message}'),
                  ],
                ),
              );
            }

            final stats = state is DashboardLoaded
                ? state.statistics
                : const DashboardStatistics(
                    totalCourses: 0,
                    totalNotes: 0,
                    totalSessions: 0,
                    totalStudyMinutes: 0,
                    todayPomodoros: 0,
                    todayPomodoroMinutes: 0,
                    weeklyMinutes: {},
                    notesNeedingReview: 0,
                  );

            return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Sección de Pomodoro
                  Text(
                    'Pomodoro Timer',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const PomodoroTimerWidget(),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Estadísticas rápidas
                  Text(
                    'Estadísticas de Hoy',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactStatCard(
                          context,
                          'Cursos',
                          stats.totalCourses.toString(),
                          Icons.school,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactStatCard(
                          context,
                          'Notas',
                          stats.totalNotes.toString(),
                          Icons.note,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactStatCard(
                          context,
                          'Sesiones',
                          stats.totalSessions.toString(),
                          Icons.play_circle,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactStatCard(
                          context,
                          'Tiempo',
                          stats.totalStudyTime,
                          Icons.timer,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Repasos pendientes
                  Text(
                    'Repasos Pendientes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            stats.notesNeedingReview > 0
                                ? Icons.calendar_today
                                : Icons.check_circle_outline,
                            size: 48,
                            color: stats.notesNeedingReview > 0
                                ? Colors.orange[400]
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            stats.notesNeedingReview > 0
                                ? '${stats.notesNeedingReview} ${stats.notesNeedingReview == 1 ? 'nota necesita' : 'notas necesitan'} repaso'
                                : 'No hay repasos programados',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: stats.notesNeedingReview > 0
                                      ? Colors.orange[700]
                                      : Colors.grey[600],
                                  fontWeight: stats.notesNeedingReview > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stats.notesNeedingReview > 0
                                ? 'Repasa estas notas para mejorar tu retención'
                                : 'Comienza a estudiar para ver tus repasos espaciados',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[500],
                                ),
                            textAlign: TextAlign.center,
                          ),
                          if (stats.notesNeedingReview > 0) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ReviewPage(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.psychology),
                              label: const Text('Iniciar Revisión'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SRSStatsPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.analytics),
                            label: const Text('Ver Estadísticas SRS'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Progreso semanal
                  Text(
                    'Progreso de la Semana',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bar_chart, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Tiempo de estudio diario',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildWeeklyChart(context, stats),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Consejos
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tip del día',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Usa la técnica Pomodoro para mantener tu concentración: 25 minutos de trabajo enfocado, seguidos de un descanso de 5 minutos.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
          },
        ),
    );
  }

  Widget _buildCompactStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(BuildContext context, DashboardStatistics stats) {
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    const maxHeight = 80.0;

    // Convert weekly minutes to hours (weekday 1-7 maps to index 0-6)
    final hours = List.generate(7, (index) {
      final weekday = index + 1; // Monday = 1, Sunday = 7
      final minutes = stats.weeklyMinutes[weekday] ?? 0;
      return minutes / 60.0; // Convert to hours
    });

    // Find max hours for scaling
    final maxHours = hours.reduce((a, b) => a > b ? a : b);
    final scale = maxHours > 0 ? maxHours : 4.0; // Default scale to 4 hours

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final height = hours[index] > 0 ? (hours[index] / scale * maxHeight) : 5.0;
        final isToday = index == DateTime.now().weekday - 1;

        return Column(
          children: [
            Container(
              width: 32,
              height: maxHeight,
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 32,
                height: height,
                decoration: BoxDecoration(
                  color: isToday
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              days[index],
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[600],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is Authenticated) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    child: Text(
                      state.user.email[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    state.user.name ?? state.user.email,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    state.user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Cerrar Sesión'),
                  onTap: () {
                    context.read<AuthBloc>().add(const LogoutRequested());
                  },
                ),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
