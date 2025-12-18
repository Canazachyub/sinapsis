import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../courses/domain/entities/course.dart';
import '../../domain/entities/note.dart';
import '../bloc/notes_bloc.dart';
import 'rich_document_editor.dart';

class NoteEditorDialog extends StatefulWidget {
  final Course course;
  final String userId;
  final Note? note;

  const NoteEditorDialog({
    super.key,
    required this.course,
    required this.userId,
    this.note,
  });

  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  final _titleController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  String _content = '';

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _content = widget.note!.content;
      _tags.addAll(widget.note!.tags);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'Nuevo Documento' : 'Editar Documento'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton.icon(
              onPressed: _saveNote,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        ),
        body: Column(
          children: [
            // Título y Tags en una fila compacta
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Título expandido
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título del documento',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tags compactos
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Tags: ', style: Theme.of(context).textTheme.labelSmall),
                          ..._tags.map((tag) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Chip(
                                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                                  onDeleted: () => setState(() => _tags.remove(tag)),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                              )),
                          ActionChip(
                            label: const Text('+ Tag', style: TextStyle(fontSize: 11)),
                            onPressed: _showAddTagDialog,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Editor de contenido - sin Card extra para ahorrar espacio
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: RichDocumentEditor(
                  initialContent: _content.isEmpty ? null : _content,
                  onContentChanged: (content) {
                    _content = content;
                  },
                ),
              ),
            ),

            // Ayuda/Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Usa la barra de herramientas para dar formato al texto, insertar código, listas, etc.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Tag'),
        content: TextField(
          controller: _tagController,
          decoration: const InputDecoration(
            labelText: 'Tag',
            hintText: 'anatomía, conceptos, difícil...',
          ),
          autofocus: true,
          onSubmitted: (_) => _addTag(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _tagController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _addTag,
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _addTag() {
    if (_tagController.text.trim().isNotEmpty) {
      setState(() {
        _tags.add(_tagController.text.trim());
        _tagController.clear();
      });
      Navigator.pop(context);
    }
  }

  void _saveNote() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor agrega un título')),
      );
      return;
    }

    if (widget.note == null) {
      // Crear documento
      context.read<NotesBloc>().add(
            CreateNoteEvent(
              courseId: widget.course.id,
              userId: widget.userId,
              title: title,
              content: _content,
              tags: _tags,
            ),
          );
    } else {
      // Actualizar documento
      context.read<NotesBloc>().add(
            UpdateNoteEvent(
              widget.note!.copyWith(
                title: title,
                content: _content,
                tags: _tags,
              ),
            ),
          );
    }

    Navigator.pop(context);
  }
}
