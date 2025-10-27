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
            // Título
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título del documento',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Anatomía del Corazón, Ciclo de Krebs...',
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Tags
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tags',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ..._tags.map((tag) => Chip(
                            label: Text(tag),
                            onDeleted: () {
                              setState(() => _tags.remove(tag));
                            },
                          )),
                      ActionChip(
                        label: const Text('+ Tag'),
                        avatar: const Icon(Icons.add, size: 16),
                        onPressed: _showAddTagDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Editor de contenido
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: RichDocumentEditor(
                      initialContent: _content.isEmpty ? null : _content,
                      onContentChanged: (content) {
                        _content = content;
                      },
                    ),
                  ),
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
