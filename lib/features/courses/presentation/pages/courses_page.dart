import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../notes/data/datasources/notes_srs_datasource.dart';
import '../../../notes/presentation/pages/notes_page.dart';
import '../../../notes/presentation/pages/review_page.dart';
import '../../../notes/presentation/widgets/importar_anotador_button.dart';
import '../bloc/courses_bloc.dart';
import '../../domain/entities/course.dart';

/// Colores disponibles: valor interno (inglés, compatible con los datos
/// existentes) → nombre en español y color.
const Map<String, (String, Color)> coloresCurso = {
  'blue': ('Azul', Colors.blue),
  'red': ('Rojo', Colors.red),
  'green': ('Verde', Colors.green),
  'purple': ('Morado', Colors.purple),
  'orange': ('Naranja', Colors.orange),
  'teal': ('Turquesa', Colors.teal),
  'pink': ('Rosa', Colors.pink),
  'indigo': ('Índigo', Colors.indigo),
};

/// Color de un curso: nombre interno o hexadecimal (`#6366F1`).
Color colorDeCurso(String valor) {
  final c = coloresCurso[valor];
  if (c != null) return c.$2;
  final hex = valor.replaceFirst('#', '');
  final n = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
  return n != null ? Color(n) : Colors.blue;
}

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final NotesSRSDataSource _srs = sl<NotesSRSDataSource>();
  final TextEditingController _busquedaCtrl = TextEditingController();
  bool _buscando = false;
  String _consulta = '';

  Map<String, ConteoCurso> _conteos = const {};
  int _colaGlobal = 0;

  /// Nuevas que aún se pueden introducir hoy (límite diario global). La
  /// cabecera cuenta vencidas + nuevas permitidas; las tarjetas usan el mismo
  /// tope para que las cifras sean coherentes.
  int _nuevasRestantes = 0;

  String? get _userId {
    final s = context.read<AuthBloc>().state;
    return s is Authenticated ? s.user.id : null;
  }

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  void _loadCourses() {
    final userId = _userId;
    if (userId != null) {
      context.read<CoursesBloc>().add(LoadCourses(userId));
    }
    _cargarConteos();
  }

  /// Notas y pendientes por curso (datos reales de SharedPreferences).
  Future<void> _cargarConteos() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final conteos = await _srs.conteoPorCurso(userId);
      final resumen = await _srs.resumen(userId);
      if (!mounted) return;
      setState(() {
        _conteos = conteos;
        _colaGlobal = resumen.colaHoy;
        _nuevasRestantes = _srs.nuevasRestantesHoy();
      });
    } catch (_) {
      // Sin conteos: las tarjetas simplemente no muestran cifras.
    }
  }

  Future<void> _abrirRepasoGlobal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReviewPage()),
    );
    if (mounted) _cargarConteos();
  }

  void _alternarBusqueda() {
    setState(() {
      _buscando = !_buscando;
      if (!_buscando) {
        _busquedaCtrl.clear();
        _consulta = '';
      }
    });
  }

  List<Course> _filtrarYOrdenar(List<Course> cursos) {
    final q = _consulta.trim().toLowerCase();
    final lista = cursos.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          (c.description?.toLowerCase().contains(q) ?? false);
    }).toList();
    // Favoritos primero; dentro de cada grupo, por nombre.
    lista.sort((a, b) {
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buscando
            ? TextField(
                controller: _busquedaCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar curso…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _consulta = v),
              )
            : const Text('Mis Cursos'),
        actions: [
          // Importar capturas del anotador de pantalla (buzón inbox/)
          if (!_buscando) const ImportarAnotadorButton(),
          IconButton(
            icon: Icon(_buscando ? Icons.close : Icons.search),
            tooltip: _buscando ? 'Cerrar búsqueda' : 'Buscar curso',
            onPressed: _alternarBusqueda,
          ),
        ],
      ),
      body: BlocConsumer<CoursesBloc, CoursesState>(
        // Recargas (tras editar o marcar favorito): mantener la lista visible
        // en vez de parpadear con el indicador de carga.
        buildWhen: (prev, curr) => !(curr is CoursesLoading && prev is CoursesLoaded),
        listener: (context, state) {
          if (state is CoursesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state is CoursesLoaded) _cargarConteos();
        },
        builder: (context, state) {
          if (state is CoursesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CoursesLoaded) {
            final cs = Theme.of(context).colorScheme;
            if (state.courses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined, size: 80, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes cursos aún',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crea tu primer curso para comenzar',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              );
            }

            final cursos = _filtrarYOrdenar(state.courses);
            final isMobile = Platform.isAndroid || Platform.isIOS;
            final screenWidth = MediaQuery.of(context).size.width;
            final edgePadding = isMobile ? 10.0 : 16.0;

            Widget tarjeta(Course c) => _CourseCard(
                  course: c,
                  conteo: _conteos[c.id],
                  nuevasRestantes: _nuevasRestantes,
                  onVolver: _cargarConteos,
                );

            final Widget lista;
            if (cursos.isEmpty) {
              lista = Center(
                child: Text(
                  'Ningún curso coincide con "${_consulta.trim()}"',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              );
            } else if (screenWidth > 700) {
              final crossAxisCount = screenWidth > 1100 ? 3 : 2;
              lista = GridView.builder(
                padding: EdgeInsets.fromLTRB(edgePadding, 0, edgePadding, 88),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 112,
                ),
                itemCount: cursos.length,
                itemBuilder: (context, index) => tarjeta(cursos[index]),
              );
            } else {
              lista = ListView.builder(
                padding: EdgeInsets.fromLTRB(edgePadding, 0, edgePadding, 88),
                itemCount: cursos.length,
                itemBuilder: (context, index) => tarjeta(cursos[index]),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(edgePadding, 12, edgePadding, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _colaGlobal > 0
                              ? '$_colaGlobal ${_colaGlobal == 1 ? 'nota para repasar' : 'notas para repasar'} hoy'
                              : 'Todo al día',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _abrirRepasoGlobal,
                        icon: const Icon(Icons.psychology),
                        label: Text('Repasar todo ($_colaGlobal)'),
                      ),
                    ],
                  ),
                ),
                Expanded(child: lista),
              ],
            );
          }

          return const Center(child: Text('Algo salió mal'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _dialogoCurso(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Curso'),
      ),
    );
  }
}

/// Selector de color con muestra (círculo) y nombre en español.
class _SelectorColor extends StatelessWidget {
  final String seleccionado;
  final ValueChanged<String> onCambio;

  const _SelectorColor({required this.seleccionado, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    final opciones = {
      ...coloresCurso,
      // Conserva un color existente que no esté en la lista (p. ej. hex).
      if (!coloresCurso.containsKey(seleccionado))
        seleccionado: ('Actual', colorDeCurso(seleccionado)),
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in opciones.entries)
          ChoiceChip(
            avatar: CircleAvatar(backgroundColor: e.value.$2, radius: 9),
            label: Text(e.value.$1),
            selected: seleccionado == e.key,
            onSelected: (sel) {
              if (sel) onCambio(e.key);
            },
          ),
      ],
    );
  }
}

/// Diálogo para crear (sin [curso]) o editar un curso.
void _dialogoCurso(BuildContext context, {Course? curso}) {
  final nameController = TextEditingController(text: curso?.name ?? '');
  final descController = TextEditingController(text: curso?.description ?? '');
  String selectedColor = curso?.color ?? 'blue';

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(curso == null ? 'Crear nuevo curso' : 'Editar curso'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre del curso',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text('Color:'),
              const SizedBox(height: 8),
              _SelectorColor(
                seleccionado: selectedColor,
                onCambio: (c) => setState(() => selectedColor = c),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final nombre = nameController.text.trim();
              if (nombre.isEmpty) return;
              final desc = descController.text.trim();
              final bloc = context.read<CoursesBloc>();
              if (curso == null) {
                final authState = context.read<AuthBloc>().state;
                if (authState is! Authenticated) return;
                bloc.add(CreateCourseEvent(
                  userId: authState.user.id,
                  name: nombre,
                  description: desc.isEmpty ? null : desc,
                  color: selectedColor,
                ));
              } else {
                bloc.add(UpdateCourseEvent(curso.copyWith(
                  name: nombre,
                  description: desc.isEmpty ? null : desc,
                  color: selectedColor,
                  updatedAt: DateTime.now(),
                )));
              }
              Navigator.pop(dialogContext);
            },
            child: Text(curso == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    ),
  );
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final ConteoCurso? conteo;
  final int nuevasRestantes;
  final VoidCallback onVolver;

  const _CourseCard({
    required this.course,
    required this.conteo,
    required this.nuevasRestantes,
    required this.onVolver,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final notas = conteo?.notas ?? 0;
    final pendientes = conteo?.pendientesHoy ?? 0;
    // Nuevas que entran hoy en la cola (con el mismo tope diario que la
    // cabecera "N notas para repasar hoy").
    final nuevasCurso = conteo?.nuevas ?? 0;
    final nuevas = nuevasCurso < nuevasRestantes ? nuevasCurso : nuevasRestantes;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotesPage(course: course)),
          );
          onVolver();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 8,
                backgroundColor: colorDeCurso(course.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (course.description != null && course.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        course.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '$notas ${notas == 1 ? 'nota' : 'notas'} · '),
                        TextSpan(
                          text: '$pendientes ${pendientes == 1 ? 'pendiente' : 'pendientes'}',
                          style: pendientes > 0
                              ? TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600)
                              : null,
                        ),
                        const TextSpan(text: ' · '),
                        TextSpan(
                          text: '$nuevas ${nuevas == 1 ? 'nueva' : 'nuevas'} hoy',
                          style: nuevas > 0
                              ? TextStyle(color: cs.primary, fontWeight: FontWeight.w600)
                              : null,
                        ),
                      ]),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: course.isFavorite ? 'Quitar de favoritos' : 'Marcar como favorito',
                icon: Icon(
                  course.isFavorite ? Icons.star : Icons.star_border,
                  color: course.isFavorite ? Colors.amber : null,
                ),
                onPressed: () {
                  context.read<CoursesBloc>().add(
                        UpdateCourseEvent(course.copyWith(isFavorite: !course.isFavorite)),
                      );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') {
                    _dialogoCurso(context, curso: course);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(context, course);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Course course) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Curso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de eliminar el curso "${course.name}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción eliminará todos los documentos del curso.',
                      style: TextStyle(
                          fontSize: 13, color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              context.read<CoursesBloc>().add(DeleteCourseEvent(course.id));
              Navigator.pop(dialogContext);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
