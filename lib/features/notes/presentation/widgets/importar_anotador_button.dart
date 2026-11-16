import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/inbox_import_service.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../courses/presentation/bloc/courses_bloc.dart';
import '../bloc/notes_bloc.dart';

/// Recarga cursos y notas tras una importación para que aparezcan
/// sin reiniciar la app.
///
/// [courseId] fuerza la recarga de notas de ese curso; si se omite, se
/// recargan las del curso que el [NotesBloc] tenga abierto (si hay alguno).
void recargarTrasImportar(BuildContext context, {String? courseId}) {
  final authState = context.read<AuthBloc>().state;
  if (authState is! Authenticated) return;
  final userId = authState.user.id;

  context.read<CoursesBloc>().add(LoadCourses(userId));

  final notesBloc = context.read<NotesBloc>();
  final notesState = notesBloc.state;
  final cursoAbierto = courseId ??
      (notesState is NotesLoaded
          ? notesState.courseId
          : notesState is NotesSaving
              ? notesState.courseId
              : null);
  if (cursoAbierto != null) {
    notesBloc.add(LoadNotes(userId, cursoAbierto));
  }
}

/// Botón de AppBar "Importar capturas del anotador".
///
/// Lee el buzón `~/Documentos/sinapsis/inbox/`, importa los ficheros
/// pendientes, recarga los blocs y muestra el resultado en un SnackBar
/// (incluido "No había capturas nuevas").
class ImportarAnotadorButton extends StatefulWidget {
  /// Curso cuyas notas deben recargarse (p. ej. en la página de notas).
  final String? courseId;

  const ImportarAnotadorButton({super.key, this.courseId});

  @override
  State<ImportarAnotadorButton> createState() => _ImportarAnotadorButtonState();
}

class _ImportarAnotadorButtonState extends State<ImportarAnotadorButton> {
  bool _importando = false;

  Future<void> _importar() async {
    if (_importando) return;
    setState(() => _importando = true);

    final resultado = await sl<InboxImportService>().importarPendientes();

    if (!mounted) return;
    setState(() => _importando = false);

    if (!resultado.sinPendientes) {
      recargarTrasImportar(context, courseId: widget.courseId);
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(resultado.mensaje),
          duration: Duration(seconds: resultado.ficherosError > 0 ? 6 : 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Importar capturas del anotador',
      onPressed: _importando ? null : _importar,
      icon: _importando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.inbox_outlined),
    );
  }
}
