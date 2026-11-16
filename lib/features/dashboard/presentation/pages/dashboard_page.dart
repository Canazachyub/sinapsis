import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../../courses/presentation/pages/courses_page.dart';
import '../../../pomodoro/presentation/widgets/pomodoro_timer_widget.dart';
import '../../../notes/presentation/pages/review_page.dart';
import '../bloc/dashboard_bloc.dart';
import 'srs_stats_page.dart';

/// Helper to check if running on a mobile platform
bool get _isMobile => Platform.isAndroid || Platform.isIOS;

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
    const ProfilePage(),
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
        body: _pages[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: _isMobile ? 11 : 13),
          ),
          indicatorShape: const StadiumBorder(),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.school_outlined, size: _isMobile ? 22 : 26),
              selectedIcon: Icon(Icons.school, size: _isMobile ? 22 : 26),
              label: 'Cursos',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, size: _isMobile ? 22 : 26),
              selectedIcon: Icon(Icons.bar_chart, size: _isMobile ? 22 : 26),
              label: 'Estadísticas',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outlined, size: _isMobile ? 22 : 26),
              selectedIcon: Icon(Icons.person, size: _isMobile ? 22 : 26),
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

            final isMobile = _isMobile;
            final edgePadding = isMobile ? 12.0 : 16.0;
            final sectionSpacing = isMobile ? 20.0 : 32.0;

            return ListView(
                padding: EdgeInsets.all(edgePadding),
                children: [
                  // Temporizador Pomodoro (el widget ya muestra su propio título)
                  const PomodoroTimerWidget(),

                  SizedBox(height: sectionSpacing),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Repaso espaciado (datos reales de las notas)
                  Text(
                    'Repaso de hoy',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildRepasoCard(context, stats),

                  SizedBox(height: sectionSpacing),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Totales
                  Text(
                    'Resumen',
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

                  SizedBox(height: sectionSpacing),
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
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
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

  Future<void> _abrirRepaso(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReviewPage()),
    );
    if (!context.mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<DashboardBloc>().add(RefreshDashboardStats(authState.user.id));
    }
  }

  Widget _buildRepasoCard(BuildContext context, DashboardStatistics stats) {
    final cs = Theme.of(context).colorScheme;
    final srs = stats.srs;
    final pendientes = srs?.pendientesHoy ?? stats.notesNeedingReview;
    final nuevas = srs?.nuevasDisponiblesHoy ?? 0;
    final cola = pendientes + nuevas;
    final retencion = srs?.retencion30;

    String titulo;
    String detalle;
    if (cola > 0) {
      titulo = pendientes > 0
          ? '$pendientes ${pendientes == 1 ? 'repaso pendiente' : 'repasos pendientes'}'
          : 'Sin repasos vencidos';
      detalle = nuevas > 0
          ? '$nuevas ${nuevas == 1 ? 'nota nueva disponible' : 'notas nuevas disponibles'} hoy'
          : 'Repasa ahora para no perder lo aprendido';
    } else {
      titulo = '¡Todo al día!';
      final proximo = srs?.proximoRepaso;
      detalle = proximo != null
          ? 'Próximo repaso: ${_fecha(proximo)}'
          : 'Aún no hay repasos programados';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  cola > 0 ? Icons.psychology : Icons.check_circle_outline,
                  size: 40,
                  color: cola > 0 ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detalle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (cola > 0)
                  FilledButton.icon(
                    onPressed: () => _abrirRepaso(context),
                    icon: const Icon(Icons.play_arrow),
                    label: Text('Repasar ($cola)'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceEvenly,
              children: [
                _miniDato(context, 'Pendientes hoy', '$pendientes', Icons.event, Colors.orange),
                _miniDato(context, 'Nuevas', '${srs?.nuevas ?? 0}', Icons.fiber_new, Colors.blue),
                _miniDato(context, 'Repasadas hoy', '${srs?.repasadasHoy ?? 0}', Icons.done_all, Colors.green),
                _miniDato(context, 'Racha', '${srs?.racha ?? 0} ${(srs?.racha ?? 0) == 1 ? 'día' : 'días'}',
                    Icons.local_fire_department, Colors.deepOrange),
                _miniDato(
                  context,
                  'Retención (30 d)',
                  retencion == null ? '—' : '${(retencion * 100).toStringAsFixed(0)} %',
                  Icons.insights,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SRSStatsPage()),
                  );
                },
                icon: const Icon(Icons.analytics),
                label: const Text('Ver estadísticas de repaso'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniDato(BuildContext context, String etiqueta, String valor, IconData icono, Color color) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            valor,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _fecha(DateTime d) {
    final hoy = DateTime.now();
    final dia = DateTime(d.year, d.month, d.day);
    final diff = dia.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    if (diff == 1) return 'mañana';
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final base = '${d.day} ${meses[d.month - 1]}';
    return diff < 7 ? '$base (en $diff días)' : base;
  }

  Widget _buildCompactStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isMobile = _isMobile;
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: isMobile ? 26 : 32),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              value,
              style: (isMobile
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineMedium)
                  ?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(BuildContext context, DashboardStatistics stats) {
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final maxHeight = _isMobile ? 60.0 : 80.0;

    // Convert weekly minutes to hours (weekday 1-7 maps to index 0-6)
    final hours = List.generate(7, (index) {
      // StatisticsDataSource usa claves 0-6 (lunes = 0).
      final minutes = stats.weeklyMinutes[index] ?? 0;
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

        final barWidth = _isMobile ? 24.0 : 32.0;
        return Column(
          children: [
            Container(
              width: barWidth,
              height: maxHeight,
              alignment: Alignment.bottomCenter,
              child: Container(
                width: barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: isToday
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
