import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/estudio_preferencias.dart';
import '../../../../core/srs/sm2.dart';
import '../../../../core/utils/titulo_contenido.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../pomodoro/presentation/bloc/pomodoro_bloc.dart';
import '../../data/datasources/notes_srs_datasource.dart';
import '../../domain/entities/note.dart';
import '../widgets/estudio_comodo.dart';
import '../widgets/study_document_viewer.dart';

/// Color de cada botón de calificación (usado en repaso, estudio y estadísticas).
Color colorCalificacion(CalificacionSrs c) => switch (c) {
      CalificacionSrs.otraVez => Colors.red.shade600,
      CalificacionSrs.dificil => Colors.orange.shade700,
      CalificacionSrs.bien => Colors.green.shade600,
      CalificacionSrs.facil => Colors.blue.shade600,
    };

/// Los 4 botones "Otra vez · <10 min / Difícil · 1 d / Bien · 3 d / Fácil · 7 d".
class BotonesCalificacion extends StatelessWidget {
  final Map<CalificacionSrs, Duration> previstos;
  final ValueChanged<CalificacionSrs>? onCalificar;

  const BotonesCalificacion({
    super.key,
    required this.previstos,
    required this.onCalificar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final c in CalificacionSrs.values) ...[
          if (c.index > 0) const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: 'Atajo: ${c.atajo}',
              child: FilledButton(
                onPressed: onCalificar == null ? null : () => onCalificar!(c),
                style: FilledButton.styleFrom(
                  backgroundColor: colorCalificacion(c),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.etiqueta,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      previstos[c] == null ? '' : Sm2.formatearIntervalo(previstos[c]!),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                    ),
                    // Tecla de atajo (1-4), discreta bajo el intervalo.
                    Text(
                      '${c.atajo}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Atajos 1-4 para calificar.
Map<ShortcutActivator, VoidCallback> atajosCalificacion(void Function(CalificacionSrs) calificar) {
  const teclas = [
    [LogicalKeyboardKey.digit1, LogicalKeyboardKey.numpad1],
    [LogicalKeyboardKey.digit2, LogicalKeyboardKey.numpad2],
    [LogicalKeyboardKey.digit3, LogicalKeyboardKey.numpad3],
    [LogicalKeyboardKey.digit4, LogicalKeyboardKey.numpad4],
  ];
  return {
    for (final c in CalificacionSrs.values)
      for (final k in teclas[c.index]) SingleActivator(k): () => calificar(c),
  };
}

/// Título de la nota, salvo que el contenido ya empiece por ese encabezado.
class TituloNotaEstudio extends StatelessWidget {
  final Note note;
  const TituloNotaEstudio({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    if (note.title.trim().isEmpty || contenidoEmpiezaConTitulo(note.content, note.title)) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Text(
        note.title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Repaso espaciado ("Cerebro"): vencidas + nuevas del día, con SM-2.
class ReviewPage extends StatefulWidget {
  final String? courseId;

  const ReviewPage({super.key, this.courseId});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final NotesSRSDataSource _srs = sl<NotesSRSDataSource>();
  final ScrollController _scroll = ScrollController();

  /// Cola pendiente; la primera es la actual. "Otra vez" la reencola al final.
  List<Note> _cola = [];
  final Set<String> _vistas = {};
  int _totalInicial = 0;
  int _repasos = 0;
  int _aciertos = 0;
  final Map<CalificacionSrs, int> _porBoton = {};

  bool _mostrando = false;
  bool _cargando = true;
  bool _guardando = false;
  bool _enfoque = false;

  // Para el estado vacío.
  DateTime? _proximo;
  int _nuevasSinLimite = 0;

  String? get _userId {
    final s = context.read<AuthBloc>().state;
    return s is Authenticated ? s.user.id : null;
  }

  @override
  void initState() {
    super.initState();
    EstudioPreferencias.cargar();
    _cargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool soloNuevas = false}) async {
    setState(() => _cargando = true);
    final userId = _userId;
    if (userId == null) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final cola = soloNuevas
          ? await _srs.nuevas(userId, courseId: widget.courseId, limite: _srs.nuevasPorDia)
          : await _srs.colaDeRepaso(userId, courseId: widget.courseId);
      final resumen = await _srs.resumen(userId, courseId: widget.courseId);
      if (!mounted) return;
      setState(() {
        _cola = cola;
        _totalInicial = cola.length;
        _vistas.clear();
        _repasos = 0;
        _aciertos = 0;
        _porBoton.clear();
        _mostrando = false;
        _proximo = resumen.proximoRepaso;
        _nuevasSinLimite = resumen.nuevas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando el repaso: $e')),
      );
    }
  }

  void _mostrar() {
    if (_cola.isEmpty || _mostrando) return;
    setState(() => _mostrando = true);
  }

  Future<void> _calificar(CalificacionSrs c) async {
    if (_cola.isEmpty || !_mostrando || _guardando) return;
    final nota = _cola.first;
    setState(() => _guardando = true);
    try {
      final nuevo = await _srs.calificar(nota.id, c);
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _repasos++;
        if (c.esAcierto) _aciertos++;
        _porBoton[c] = (_porBoton[c] ?? 0) + 1;
        _vistas.add(nota.id);
        _cola = [
          ..._cola.skip(1),
          // "Otra vez": vuelve a salir al final de esta sesión.
          if (c == CalificacionSrs.otraVez) nota.copyWith(srs: nuevo),
        ];
        _mostrando = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando el repaso: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enCurso = !_cargando && _cola.isNotEmpty;
    return AtajosEstudio(
      enfoque: _enfoque,
      autofocus: true,
      onAlternarEnfoque: () => setState(() => _enfoque = !_enfoque),
      extra: {
        if (enCurso) const SingleActivator(LogicalKeyboardKey.space): _mostrar,
        if (enCurso && _mostrando) ...atajosCalificacion(_calificar),
      },
      child: Scaffold(
        appBar: _enfoque
            ? null
            : AppBar(
                title: Text(widget.courseId == null ? 'Repaso' : 'Repaso del curso'),
                actions: [
                  const BotonesEscalaTexto(),
                  IconButton(
                    icon: const Icon(Icons.timer),
                    tooltip: 'Iniciar Pomodoro',
                    onPressed: () {
                      if (_userId == null) return;
                      context.read<PomodoroBloc>().add(
                            StartPomodoro(
                              courseId: widget.courseId,
                              noteId: _cola.isNotEmpty ? _cola.first.id : null,
                            ),
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pomodoro iniciado para este repaso')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    tooltip: 'Modo enfoque (F11)',
                    onPressed: () => setState(() => _enfoque = true),
                  ),
                ],
              ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _cola.isNotEmpty
                ? _tarjeta()
                : _repasos > 0
                    ? _resumenSesion()
                    : _todoAlDia(),
      ),
    );
  }

  // ---------------- Estados ----------------

  Widget _todoAlDia() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade400),
            const SizedBox(height: 24),
            Text('¡Todo al día!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _proximo != null
                  ? 'Próximo repaso: ${_formatearFecha(_proximo!)}'
                  : 'No hay repasos programados todavía',
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
            ),
            if (_nuevasSinLimite > 0) ...[
              const SizedBox(height: 24),
              Text(
                '$_nuevasSinLimite ${_nuevasSinLimite == 1 ? 'nota nueva disponible' : 'notas nuevas disponibles'}'
                ' (límite diario alcanzado)',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _cargar(soloNuevas: true),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Estudiar ahora'),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumenSesion() {
    final cs = Theme.of(context).colorScheme;
    final pct = _repasos == 0 ? 0 : (_aciertos * 100 / _repasos).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, size: 80, color: Colors.amber.shade400),
            const SizedBox(height: 24),
            Text('¡Sesión completada!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '${_vistas.length} ${_vistas.length == 1 ? 'nota' : 'notas'} · $_repasos '
              '${_repasos == 1 ? 'respuesta' : 'respuestas'} · $_aciertos aciertos ($pct %)',
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final c in CalificacionSrs.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: colorCalificacion(c), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('${c.etiqueta}: ${_porBoton[c] ?? 0}'),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
                OutlinedButton.icon(
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Buscar más repasos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta() {
    final cs = Theme.of(context).colorScheme;
    final nota = _cola.first;
    final hechas = _vistas.length;
    final total = _totalInicial == 0 ? 1 : _totalInicial;
    final previstos = _srs.previsualizar(nota.srs);
    final ancho = _enfoque ? EstudioLayout.anchoLecturaEnfoque : EstudioLayout.anchoLecturaNormal;

    final columna = Column(
      children: [
        // Indicador único de progreso: "3 de 7" + barra coherente.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text('${(hechas + 1).clamp(1, total)} de $total',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: LinearProgressIndicator(
                  value: hechas / total,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              _chipEtapa(nota.srs),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 32).clamp(0.0, ancho).toDouble();
            return SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: SizedBox(
                  width: w,
                  child: EscalaTextoEstudio(
                    child: AnchoContenidoEstudio(
                      ancho: w,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TituloNotaEstudio(note: nota),
                          StudyDocumentViewer(
                            key: ValueKey('${nota.id}-$_repasos'),
                            content: nota.content,
                            showOcclusions: _mostrando,
                            sinMarco: _enfoque,
                          ),
                          if (_mostrando && !nota.srs.esNueva) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Intervalo actual: ${nota.srs.intervalo} ${nota.srs.intervalo == 1 ? 'día' : 'días'}'
                              ' · Facilidad ${nota.srs.ease.toStringAsFixed(2)}'
                              ' · Olvidos ${nota.srs.lapsos}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ancho),
              child: _mostrando
                  ? BotonesCalificacion(
                      previstos: previstos,
                      onCalificar: _guardando ? null : _calificar,
                    )
                  : FilledButton.icon(
                      onPressed: _mostrar,
                      icon: const Icon(Icons.visibility),
                      label: const Text('Mostrar  (espacio)'),
                      style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                    ),
            ),
          ),
        ),
      ],
    );

    if (!_enfoque) return columna;
    return SafeArea(
      child: Stack(
        children: [
          columna,
          Positioned(
            top: 6,
            right: 12,
            child: BarraFlotanteEnfoque(onSalir: () => setState(() => _enfoque = false)),
          ),
        ],
      ),
    );
  }

  Widget _chipEtapa(EstadoSrs s) {
    final color = switch (s.etapa) {
      'Nueva' => Colors.blue,
      'Aprendiendo' => Colors.red,
      'Joven' => Colors.orange,
      _ => Colors.green,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(s.etapa, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _formatearFecha(DateTime d) {
    final hoy = DateTime.now();
    final dias = DateTime(d.year, d.month, d.day)
        .difference(DateTime(hoy.year, hoy.month, hoy.day))
        .inDays;
    const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
      'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final base = '${d.day} de ${meses[d.month - 1]}';
    if (dias <= 0) return 'hoy';
    if (dias == 1) return 'mañana ($base)';
    return '$base (en $dias días)';
  }
}
