import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Definición centralizada de atajos de teclado para el editor
class EditorShortcuts {
  EditorShortcuts._();

  // Formato de texto básico
  static const bold = SingleActivator(LogicalKeyboardKey.keyB, control: true);
  static const italic = SingleActivator(LogicalKeyboardKey.keyI, control: true);
  static const underline = SingleActivator(LogicalKeyboardKey.keyU, control: true);
  static const strikethrough = SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true, alt: true);

  // Superíndice y subíndice
  static const superscript = SingleActivator(LogicalKeyboardKey.period, control: true);
  static const subscript = SingleActivator(LogicalKeyboardKey.comma, control: true);

  // Enlaces e imágenes
  static const link = SingleActivator(LogicalKeyboardKey.keyK, control: true);
  static const image = SingleActivator(LogicalKeyboardKey.keyI, control: true, shift: true);

  // Código
  static const inlineCode = SingleActivator(LogicalKeyboardKey.backquote, control: true);
  static const codeBlock = SingleActivator(LogicalKeyboardKey.backquote, control: true, shift: true);

  // Encabezados
  static const header1 = SingleActivator(LogicalKeyboardKey.digit1, control: true);
  static const header2 = SingleActivator(LogicalKeyboardKey.digit2, control: true);
  static const header3 = SingleActivator(LogicalKeyboardKey.digit3, control: true);
  static const header4 = SingleActivator(LogicalKeyboardKey.digit4, control: true);
  static const header5 = SingleActivator(LogicalKeyboardKey.digit5, control: true);
  static const header6 = SingleActivator(LogicalKeyboardKey.digit6, control: true);

  // Listas
  static const bulletList = SingleActivator(LogicalKeyboardKey.keyL, control: true);
  static const numberedList = SingleActivator(LogicalKeyboardKey.keyL, control: true, shift: true);
  static const taskList = SingleActivator(LogicalKeyboardKey.keyT, control: true);

  // Citas y separadores
  static const quote = SingleActivator(LogicalKeyboardKey.quote, control: true, shift: true);
  static const divider = SingleActivator(LogicalKeyboardKey.minus, control: true, shift: true);

  // Búsqueda y reemplazo
  static const find = SingleActivator(LogicalKeyboardKey.keyF, control: true);
  static const replace = SingleActivator(LogicalKeyboardKey.keyH, control: true);

  // Transformaciones de texto
  static const uppercase = SingleActivator(LogicalKeyboardKey.keyM, control: true, shift: true);
  static const lowercase = SingleActivator(LogicalKeyboardKey.keyM, control: true);
  static const capitalize = SingleActivator(LogicalKeyboardKey.keyM, control: true, alt: true);

  // Oclusiones (mantener existentes)
  static const textOcclusion = SingleActivator(LogicalKeyboardKey.keyO, control: true);
  static const imageOcclusion = SingleActivator(LogicalKeyboardKey.keyO, control: true, shift: true);

  // Vista previa y ayuda
  static const preview = SingleActivator(LogicalKeyboardKey.f6);
  static const help = SingleActivator(LogicalKeyboardKey.f1);

  // Limpiar formato
  static const clearFormat = SingleActivator(LogicalKeyboardKey.backslash, control: true);

  // Resaltado
  static const highlight = SingleActivator(LogicalKeyboardKey.keyH, control: true, shift: true, alt: true);

  // Pegar especial
  static const pasteMarkdown = SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true);
}

/// Intenciones para las acciones del editor
class EditorActions {
  EditorActions._();

  // Acciones personalizadas
  static const String boldAction = 'bold';
  static const String italicAction = 'italic';
  static const String underlineAction = 'underline';
  static const String strikethroughAction = 'strikethrough';
  static const String superscriptAction = 'superscript';
  static const String subscriptAction = 'subscript';
  static const String linkAction = 'link';
  static const String imageAction = 'image';
  static const String inlineCodeAction = 'inlineCode';
  static const String codeBlockAction = 'codeBlock';
  static const String header1Action = 'header1';
  static const String header2Action = 'header2';
  static const String header3Action = 'header3';
  static const String header4Action = 'header4';
  static const String header5Action = 'header5';
  static const String header6Action = 'header6';
  static const String bulletListAction = 'bulletList';
  static const String numberedListAction = 'numberedList';
  static const String taskListAction = 'taskList';
  static const String quoteAction = 'quote';
  static const String dividerAction = 'divider';
  static const String findAction = 'find';
  static const String replaceAction = 'replace';
  static const String uppercaseAction = 'uppercase';
  static const String lowercaseAction = 'lowercase';
  static const String capitalizeAction = 'capitalize';
  static const String textOcclusionAction = 'textOcclusion';
  static const String imageOcclusionAction = 'imageOcclusion';
  static const String previewAction = 'preview';
  static const String helpAction = 'help';
  static const String clearFormatAction = 'clearFormat';
  static const String highlightAction = 'highlight';
  static const String pasteMarkdownAction = 'pasteMarkdown';
}

/// Descripción de atajos para mostrar al usuario
class ShortcutDescriptions {
  ShortcutDescriptions._();

  static const Map<String, String> descriptions = {
    'Ctrl+B': 'Negrita',
    'Ctrl+I': 'Cursiva',
    'Ctrl+U': 'Subrayado',
    'Ctrl+Shift+Alt+S': 'Tachado',
    'Ctrl+.': 'Superíndice',
    'Ctrl+,': 'Subíndice',
    'Ctrl+K': 'Insertar enlace',
    'Ctrl+Shift+I': 'Insertar imagen',
    'Ctrl+`': 'Código inline',
    'Ctrl+Shift+`': 'Bloque de código',
    'Ctrl+1..6': 'Encabezados H1-H6',
    'Ctrl+L': 'Lista con viñetas',
    'Ctrl+Shift+L': 'Lista numerada',
    'Ctrl+T': 'Lista de tareas',
    'Ctrl+Shift+"': 'Cita',
    'Ctrl+Shift+-': 'Separador',
    'Ctrl+F': 'Buscar',
    'Ctrl+H': 'Reemplazar',
    'Ctrl+Shift+M': 'MAYÚSCULAS',
    'Ctrl+M': 'minúsculas',
    'Ctrl+Alt+M': 'Capitalizar',
    'Ctrl+O': 'Oclusión de texto',
    'Ctrl+Shift+O': 'Oclusión de imagen',
    'F6': 'Vista previa',
    'F1': 'Ayuda',
    'Ctrl+\\': 'Limpiar formato',
    'Ctrl+Shift+Alt+H': 'Resaltar',
    'Ctrl+Shift+V': 'Pegar Markdown',
  };
}
