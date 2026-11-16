import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/srs/sm2.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../notes/data/datasources/notes_srs_datasource.dart';
import '../../../notes/presentation/pages/review_page.dart' show colorCalificacion;

/// Estadísticas del repaso espaciado, calculadas con los datos reales
/// (notas en SharedPreferences + historial `SRS_HISTORIAL`). Nunca inventa:
/// si no hay datos se muestra "—".
class SRSStatsPage extends StatefulWidget {
  const SRSStatsPage({super.key});

  @override
  State<SRSStatsPage> createState() => _SRSStatsPageState();
}

class _SRSStatsPageState extends State<SRSStatsPage> {
  final NotesSRSDataSource _srs = sl<NotesSRSDataSource>();
  ResumenSrs? _resumen;
  Map<String, DiaSrs> _historial = const {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final r = await _srs.resumen(authState.user.id);
      if (!mounted) return;
      setState(() {
        _resumen = r;
        _historial = _srs.historial();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando estadísticas: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas de repaso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _resumen == null
              ? const Center(child: Text('No hay datos disponibles'))
              : _contenido(_resumen!),
    );
  }

  Widget _contenido(ResumenSrs r) {
    final cs = Theme.of(context).colorScheme;
    final titulo = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.analytics, color: cs.primary),
                      const SizedBox(width: 8),
                      Text('Resumen', style: titulo),
                    ]),
                    const SizedBox(height: 12),
                    _fila('Total de notas', '${r.totalNotas}'),
                    _fila('Pendientes hoy', '${r.pendientesHoy}'),
                    _fila('Nuevas disponibles hoy', '${r.nuevasDisponiblesHoy}'),
                    _fila('Repasadas hoy', '${r.repasadasHoy}'),
                    _fila('Racha', '${r.racha} ${r.racha == 1 ? 'día' : 'días'}'),
                    _fila(
                      'Retención (últimos 30 días)',
                      r.retencion30 == null
                          ? '—'
                          : '${(r.retencion30! * 100).toStringAsFixed(1)} %  (${r.repasos30} repasos)',
                    ),
                    _fila('Repasos totales registrados', '${r.repasosTotales}'),
                    _fila('Factor de facilidad medio',
                        r.easePromedio == null ? '—' : r.easePromedio!.toStringAsFixed(2)),
                    _fila('Olvidos (lapsos)', '${r.lapsosTotales}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notas por etapa', style: titulo),
                    const SizedBox(height: 16),
                    if (r.totalNotas == 0)
                      const Text('No hay notas todavía')
                    else ...[
                      _barra('Nuevas (sin estudiar)', r.nuevas, r.totalNotas, Colors.blue),
                      _barra('Aprendiendo (falladas hoy)', r.aprendiendo, r.totalNotas, Colors.red),
                      _barra('Jóvenes (intervalo < 21 d)', r.jovenes, r.totalNotas, Colors.orange),
                      _barra('Maduras (intervalo ≥ 21 d)', r.maduras, r.totalNotas, Colors.green),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Respuestas (últimos 30 días)', style: titulo),
                    const SizedBox(height: 16),
                    if (r.repasos30 == 0)
                      Text('Aún no hay repasos registrados.',
                          style: TextStyle(color: cs.onSurfaceVariant))
                    else
                      for (final c in CalificacionSrs.values)
                        _barra(c.etiqueta, r.porBoton30[c] ?? 0, r.repasos30, colorCalificacion(c)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        for (final c in CalificacionSrs.values) _leyenda(c.etiqueta, colorCalificacion(c)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Repasos por día (últimas 2 semanas)', style: titulo),
                    const SizedBox(height: 16),
                    _graficoDias(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline, color: cs.primary),
                      const SizedBox(width: 8),
                      Text('Cómo funciona (SM-2, como Anki)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      'Cada nota tiene un intervalo y un factor de facilidad que se ajustan '
                      'según tu respuesta. Las notas nuevas se repasan a 1 y luego a 6 días; '
                      'después el intervalo se multiplica por el factor.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    for (final linea in const [
                      (CalificacionSrs.otraVez, 'vuelve en unos minutos; reinicia el intervalo y cuenta un olvido'),
                      (CalificacionSrs.dificil, 'intervalo ×1,2 y facilidad −0,15'),
                      (CalificacionSrs.bien, 'intervalo × factor de facilidad'),
                      (CalificacionSrs.facil, 'intervalo × factor × 1,3 y facilidad +0,15'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _punto(colorCalificacion(linea.$1)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                    text: '${linea.$1.etiqueta}: ',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: linea.$2),
                                ]),
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15))),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _barra(String etiqueta, int valor, int total, Color color) {
    final cs = Theme.of(context).colorScheme;
    final p = total > 0 ? valor / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _punto(color),
              const SizedBox(width: 8),
              Expanded(child: Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.w500))),
              Text('$valor (${(p * 100).toStringAsFixed(0)} %)',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: p,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _punto(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _leyenda(String texto, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _punto(color),
          const SizedBox(width: 6),
          Text(texto, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        ],
      );

  Widget _graficoDias() {
    final cs = Theme.of(context).colorScheme;
    final hoy = DateTime.now();
    final dias = List.generate(14, (i) => DateTime(hoy.year, hoy.month, hoy.day - 13 + i));
    String clave(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final valores = [for (final d in dias) _historial[clave(d)]?.repasos ?? 0];
    final maximo = valores.fold<int>(0, (a, b) => a > b ? a : b);
    if (maximo == 0) {
      return Text('Sin repasos en las últimas dos semanas.', style: TextStyle(color: cs.onSurfaceVariant));
    }
    const alto = 90.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < dias.length; i++)
          Expanded(
            child: Tooltip(
              message: '${dias[i].day}/${dias[i].month}: ${valores[i]} repasos',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(valores[i] > 0 ? '${valores[i]}' : '',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Container(
                    height: valores[i] == 0 ? 2 : alto * valores[i] / maximo,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == dias.length - 1 ? cs.primary : cs.primary.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${dias[i].day}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
