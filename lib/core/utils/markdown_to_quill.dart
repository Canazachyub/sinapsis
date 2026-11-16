import 'package:markdown/markdown.dart' as md;
import 'dart:convert';

/// Convierte texto Markdown a Delta JSON de flutter_quill
/// Soporta todas las reglas de sintaxis Markdown estándar
class MarkdownToQuill {
  static String convert(String markdownText) {
    // Normalizar viñetas "•", "–" de texto pegado a listas Markdown
    final conVinetas = _fueraDeCodigo(markdownText, _normalizarVinetas);

    // Pre-procesar reglas horizontales PRIMERO (antes de otros procesamientos)
    final textWithRules = _fueraDeCodigo(conVinetas, _preprocessHorizontalRules);

    // Pre-procesar el texto para formatos extendidos
    final processedText = _fueraDeCodigo(textWithRules, _preprocessExtendedMarkdown);

    // Pre-procesar tablas antes de parsear
    final textWithTables = _fueraDeCodigo(processedText, _preprocessTables);

    // Parsear markdown con extensiones completas
    final document = md.Document(
      encodeHtml: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    final nodes = document.parseLines(textWithTables.split('\n'));
    final deltaOps = <Map<String, dynamic>>[];

    for (final node in nodes) {
      _processNode(node, deltaOps);
    }

    // Post-procesar para convertir marcadores de tabla a embeds
    _processTableEmbeds(deltaOps);

    // Post-procesar para convertir marcadores de reglas horizontales
    _processHorizontalRuleEmbeds(deltaOps);

    // Etiquetas HTML en línea (<u>, <sup>, <sub>, <mark>, <br>...) → atributos
    final ops = _procesarHtmlEnLinea(deltaOps);

    // Asegurar que termine con newline
    if (ops.isEmpty || ops.last['insert'] != '\n') {
      ops.add({'insert': '\n'});
    }

    return jsonEncode(ops);
  }

  /// Aplica [fn] solo a los tramos de texto que NO están dentro de bloques
  /// de código cercados (``` o ~~~), para no alterar el código.
  static String _fueraDeCodigo(String texto, String Function(String) fn) {
    final lineas = texto.split('\n');
    final salida = <String>[];
    final tramo = <String>[];
    String? marca; // carácter de la valla abierta
    int largo = 0;

    void volcar() {
      if (tramo.isEmpty) return;
      salida.addAll(fn(tramo.join('\n')).split('\n'));
      tramo.clear();
    }

    for (final linea in lineas) {
      final t = linea.trimLeft();
      final m = RegExp(r'^(`{3,}|~{3,})').firstMatch(t);
      if (marca == null) {
        if (m != null) {
          volcar();
          marca = m.group(1)![0];
          largo = m.group(1)!.length;
          salida.add(linea);
        } else {
          tramo.add(linea);
        }
      } else {
        salida.add(linea);
        if (m != null && m.group(1)![0] == marca && m.group(1)!.length >= largo
            && t.substring(m.group(1)!.length).trim().isEmpty) {
          marca = null;
        }
      }
    }
    volcar();
    return salida.join('\n');
  }

  /// Convierte viñetas tipográficas (•, ◦, ▪, ‣, ∙) y guiones largos (–, —)
  /// repetidos en listas Markdown ("- ").
  static String _normalizarVinetas(String texto) {
    final lineas = texto.split('\n');
    final reVineta = RegExp(r'^(\s*)[•◦▪▫‣∙●○■□]\s+(.*)$');
    final reGuion = RegExp(r'^(\s*)[–—]\s+(.*)$');
    for (int i = 0; i < lineas.length; i++) {
      final m = reVineta.firstMatch(lineas[i]);
      if (m != null) {
        lineas[i] = '${m.group(1)}- ${m.group(2)}';
        continue;
      }
      // Guion largo: solo si forma una racha de >= 2 líneas (evita diálogos)
      if (reGuion.hasMatch(lineas[i])) {
        final vecina = (i > 0 && reGuion.hasMatch(lineas[i - 1])) ||
            (i + 1 < lineas.length && reGuion.hasMatch(lineas[i + 1]));
        if (vecina) {
          final g = reGuion.firstMatch(lineas[i])!;
          lineas[i] = '${g.group(1)}- ${g.group(2)}';
        }
      }
    }
    return lineas.join('\n');
  }

  static final _reEtiquetaEnLinea = RegExp(
    r'<(/?)(u|sup|sub|mark|br|strong|b|em|i|s|del)\s*/?>',
    caseSensitive: false,
  );

  /// Convierte etiquetas HTML en línea que el parser Markdown deja como texto
  /// literal (`<u>`, `<sup>`, `<sub>`, `<mark>`, `<br>`, ...) en atributos Delta.
  static List<Map<String, dynamic>> _procesarHtmlEnLinea(
      List<Map<String, dynamic>> ops) {
    final salida = <Map<String, dynamic>>[];
    final activos = <String, int>{};

    // Un tramo = ops hasta el siguiente salto de línea. Se omite si es código.
    int inicio = 0;
    while (inicio < ops.length) {
      int fin = inicio;
      while (fin < ops.length && ops[fin]['insert'] != '\n') {
        fin++;
      }
      final esCodigo = fin < ops.length &&
          (ops[fin]['attributes'] is Map) &&
          (ops[fin]['attributes'] as Map)['code-block'] == true;
      activos.clear();
      for (int i = inicio; i <= fin && i < ops.length; i++) {
        final op = ops[i];
        final ins = op['insert'];
        final attrs = op['attributes'] as Map<String, dynamic>?;
        final esCodigoEnLinea = attrs != null && attrs['code'] == true;
        if (ins is! String || esCodigo || esCodigoEnLinea || !ins.contains('<')) {
          salida.add(op);
          continue;
        }
        int ultimo = 0;
        bool saltarNewline = false;
        void literal(String t) {
          if (saltarNewline && t.startsWith('\n')) {
            t = t.substring(1);
          }
          saltarNewline = false;
          if (t.isEmpty) return;
          final extra = <String, dynamic>{...?attrs};
          activos.forEach((tag, n) {
            if (n <= 0) return;
            switch (tag) {
              case 'u':
                extra['underline'] = true;
              case 'sup':
                extra['script'] = 'super';
              case 'sub':
                extra['script'] = 'sub';
              case 'mark':
                extra['highlight'] = true;
              case 'strong':
              case 'b':
                extra['bold'] = true;
              case 'em':
              case 'i':
                extra['italic'] = true;
              case 's':
              case 'del':
                extra['strike'] = true;
            }
          });
          salida.add({
            'insert': t,
            if (extra.isNotEmpty) 'attributes': extra,
          });
        }

        for (final m in _reEtiquetaEnLinea.allMatches(ins)) {
          literal(ins.substring(ultimo, m.start));
          ultimo = m.end;
          final tag = m.group(2)!.toLowerCase();
          if (tag == 'br') {
            salida.add({'insert': '\n'});
            saltarNewline = true;
            continue;
          }
          saltarNewline = false;
          if (m.group(1) == '/') {
            activos[tag] = (activos[tag] ?? 1) - 1;
          } else {
            activos[tag] = (activos[tag] ?? 0) + 1;
          }
        }
        literal(ins.substring(ultimo));
      }
      inicio = fin + 1;
    }
    return salida;
  }

  /// Pre-procesa reglas horizontales (---, ***, ___)
  static String _preprocessHorizontalRules(String text) {
    final lines = text.split('\n');
    final result = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Verificar que no sea un subrayado de encabezado (=== o ---)
      // Los subrayados de encabezado requieren una línea anterior con texto
      bool isHeaderUnderline = false;
      if (i > 0 && (trimmed.startsWith('===') || trimmed.startsWith('---'))) {
        final prevLine = lines[i - 1].trim();
        if (prevLine.isNotEmpty && !prevLine.startsWith('#')) {
          // Es un subrayado de encabezado, no una regla horizontal
          isHeaderUnderline = true;
        }
      }

      // Detectar reglas horizontales: 3 o más -, *, o _ (solo del mismo tipo)
      // Debe estar en línea vacía (no precedida por texto)
      if (!isHeaderUnderline && (i == 0 || lines[i - 1].trim().isEmpty)) {
        // Solo guiones (al menos 3)
        if (RegExp(r'^[\s]*-[\s]*-[\s]*-[\s-]*$').hasMatch(trimmed) && !trimmed.contains('*') && !trimmed.contains('_')) {
          result.add('%%%HORIZONTAL_RULE%%%');
          continue;
        }
        // Solo asteriscos (al menos 3)
        if (RegExp(r'^[\s]*\*[\s]*\*[\s]*\*[\s\*]*$').hasMatch(trimmed) && !trimmed.contains('-') && !trimmed.contains('_')) {
          result.add('%%%HORIZONTAL_RULE%%%');
          continue;
        }
        // Solo guiones bajos (al menos 3)
        if (RegExp(r'^[\s]*_[\s]*_[\s]*_[\s_]*$').hasMatch(trimmed) && !trimmed.contains('-') && !trimmed.contains('*')) {
          result.add('%%%HORIZONTAL_RULE%%%');
          continue;
        }
      }

      result.add(line);
    }

    return result.join('\n');
  }

  /// Procesa los marcadores de reglas horizontales
  static void _processHorizontalRuleEmbeds(List<Map<String, dynamic>> deltaOps) {
    for (int i = 0; i < deltaOps.length; i++) {
      final op = deltaOps[i];
      if (op['insert'] is String && (op['insert'] as String).contains('%%%HORIZONTAL_RULE%%%')) {
        // Reemplazar con texto simple temporalmente
        deltaOps[i] = {'insert': '---'};
        // Asegurar que hay un newline después
        if (i + 1 >= deltaOps.length || deltaOps[i + 1]['insert'] != '\n') {
          deltaOps.insert(i + 1, {'insert': '\n'});
        }
      }
    }
  }

  /// Pre-procesa tablas Markdown y las convierte a embeds de tabla
  static String _preprocessTables(String text) {
    final lines = text.split('\n');
    final result = <String>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i];

      // Detectar inicio de tabla (línea con pipes)
      if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
        // Verificar si la siguiente línea es el separador
        if (i + 1 < lines.length && _isTableSeparator(lines[i + 1])) {
          // Es una tabla
          final tableLines = <String>[line];
          tableLines.add(lines[i + 1]); // separador
          i += 2;

          // Recoger el resto de las filas
          while (i < lines.length && lines[i].trim().startsWith('|') && lines[i].trim().endsWith('|')) {
            tableLines.add(lines[i]);
            i++;
          }

          // Convertir tabla a embed
          result.add(_convertTableToEmbed(tableLines));
          continue;
        }
      }

      result.add(line);
      i++;
    }

    return result.join('\n');
  }

  static bool _isTableSeparator(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) return false;

    // Verificar que solo contenga |, -, : y espacios
    return RegExp(r'^\|[\s\-:]+\|$').hasMatch(trimmed.replaceAll('|', ' | '));
  }

  static String _convertTableToEmbed(List<String> tableLines) {
    if (tableLines.length < 3) return tableLines.join('\n');

    // Parsear encabezados
    final headers = _parseTableRow(tableLines[0]);
    final columns = headers.length;

    // Parsear filas de datos (saltar separador)
    final rows = <List<String>>[];
    rows.add(headers); // Primera fila son los encabezados

    for (int i = 2; i < tableLines.length; i++) {
      final row = _parseTableRow(tableLines[i]);
      // Asegurar que tenga el mismo número de columnas
      while (row.length < columns) {
        row.add('');
      }
      rows.add(row.take(columns).toList());
    }

    // Crear JSON de tabla
    final tableData = {
      'rows': rows.length,
      'columns': columns,
      'cells': rows,
    };

    // Retornar marcador especial que será procesado después
    return '%%%TABLE_EMBED%%%${jsonEncode(tableData)}%%%';
  }

  static List<String> _parseTableRow(String line) {
    // Remover pipes inicial y final
    String cleaned = line.trim();
    if (cleaned.startsWith('|')) cleaned = cleaned.substring(1);
    if (cleaned.endsWith('|')) cleaned = cleaned.substring(0, cleaned.length - 1);

    // Dividir por pipes y limpiar espacios
    return cleaned.split('|').map((cell) => cell.trim()).toList();
  }

  /// Procesa los marcadores de tabla y los convierte a embeds
  static void _processTableEmbeds(List<Map<String, dynamic>> deltaOps) {
    for (int i = 0; i < deltaOps.length; i++) {
      final op = deltaOps[i];
      if (op['insert'] is String) {
        final text = op['insert'] as String;

        // Buscar marcadores de tabla
        if (text.contains('%%%TABLE_EMBED%%%')) {
          final regex = RegExp(r'%%%TABLE_EMBED%%%(.*?)%%%');
          final matches = regex.allMatches(text);

          if (matches.isNotEmpty) {
            final newOps = <Map<String, dynamic>>[];
            int lastEnd = 0;

            for (final match in matches) {
              // Agregar texto antes del marcador
              if (match.start > lastEnd) {
                final beforeText = text.substring(lastEnd, match.start);
                if (beforeText.isNotEmpty) {
                  newOps.add({'insert': beforeText});
                }
              }

              // Convertir marcador a embed de tabla
              try {
                final tableJson = match.group(1)!;
                final tableData = jsonDecode(tableJson) as Map<String, dynamic>;

                // Crear embed de tabla
                newOps.add({
                  'insert': {
                    'table': jsonEncode(tableData),
                  }
                });
                newOps.add({'insert': '\n'});
              } catch (e) {
                print('⚠️ Error procesando tabla embed: $e');
                // Si falla, mantener el marcador como texto
                newOps.add({'insert': match.group(0)});
              }

              lastEnd = match.end;
            }

            // Agregar texto después del último marcador
            if (lastEnd < text.length) {
              final afterText = text.substring(lastEnd);
              if (afterText.isNotEmpty) {
                newOps.add({'insert': afterText});
              }
            }

            // Reemplazar la operación original con las nuevas
            deltaOps.removeAt(i);
            deltaOps.insertAll(i, newOps);
            i += newOps.length - 1; // Ajustar índice
          }
        }
      }
    }
  }

  /// Pre-procesa formatos extendidos que no son parte de MD estándar.
  /// Trabaja línea a línea (no cruza saltos de línea), respeta caracteres
  /// escapados con `\` y no toca las filas de tabla (`| ... |`).
  static String _preprocessExtendedMarkdown(String text) {
    final lineas = text.split('\n');
    for (int i = 0; i < lineas.length; i++) {
      var l = lineas[i];
      if (l.trimLeft().startsWith('|')) continue;

      // REGLA: Salto de línea dentro del mismo párrafo (2 espacios + Enter)
      if (i < lineas.length - 1 && RegExp(r'\S[ ]{2,}$').hasMatch(l)) {
        l = '${l.trimRight()}<br>';
      }

      // Superíndice: ^text^ → <sup>text</sup>
      l = l.replaceAllMapped(
        RegExp(r'(?<!\\)\^([^^]+)(?<!\\)\^'),
        (m) => '<sup>${m.group(1)}</sup>',
      );

      // Subíndice: ~text~ (pero no ~~text~~) → <sub>text</sub>
      l = l.replaceAllMapped(
        RegExp(r'(?<![~\\])~([^~]+)(?<!\\)~(?!~)'),
        (m) => '<sub>${m.group(1)}</sub>',
      );

      // Resaltado: ==text== → <mark>text</mark>
      l = l.replaceAllMapped(
        RegExp(r'(?<!\\)==([^=]+)==(?!=)'),
        (m) => '<mark>${m.group(1)}</mark>',
      );
      lineas[i] = l;
    }
    return lineas.join('\n');
  }

  static void _processNode(md.Node node, List<Map<String, dynamic>> deltaOps) {
    if (node is md.Element) {
      switch (node.tag) {
        case 'h1':
          _processInlineChildren(node, deltaOps, {'header': 1});
          deltaOps.add({'insert': '\n', 'attributes': {'header': 1}});
          break;
        case 'h2':
          _processInlineChildren(node, deltaOps, {'header': 2});
          deltaOps.add({'insert': '\n', 'attributes': {'header': 2}});
          break;
        case 'h3':
          _processInlineChildren(node, deltaOps, {'header': 3});
          deltaOps.add({'insert': '\n', 'attributes': {'header': 3}});
          break;
        case 'h4':
          _processInlineChildren(node, deltaOps, {'header': 4});
          deltaOps.add({'insert': '\n', 'attributes': {'header': 4}});
          break;
        case 'h5':
          _processInlineChildren(node, deltaOps, {'header': 5});
          deltaOps.add({'insert': '\n', 'attributes': {'header': 5}});
          break;
        case 'h6':
          _processInlineChildren(node, deltaOps, {'header': 6});
          deltaOps.add({'insert': '\n', 'attributes': {'header': 6}});
          break;
        case 'p':
          _processInlineChildren(node, deltaOps, null);
          deltaOps.add({'insert': '\n'});
          break;
        case 'strong':
        case 'b':
          _processInlineChildren(node, deltaOps, {'bold': true});
          break;
        case 'em':
        case 'i':
          _processInlineChildren(node, deltaOps, {'italic': true});
          break;
        case 'u':
          _processInlineChildren(node, deltaOps, {'underline': true});
          break;
        case 'del':
        case 's':
          _processInlineChildren(node, deltaOps, {'strike': true});
          break;
        case 'code':
          if (node.children != null && node.children!.isNotEmpty) {
            final text = _extractText(node);
            deltaOps.add({
              'insert': text,
              'attributes': {'code': true},
            });
          }
          break;
        case 'br':
          // Salto de línea dentro de un párrafo (2 espacios + Enter)
          deltaOps.add({'insert': '\n'});
          break;
        case 'pre':
          // Un salto de línea con atributo code-block por CADA línea (formato Delta estándar)
          var codeText = _extractText(node);
          if (codeText.endsWith('\n')) {
            codeText = codeText.substring(0, codeText.length - 1);
          }
          for (final linea in codeText.split('\n')) {
            if (linea.isNotEmpty) deltaOps.add({'insert': linea});
            deltaOps.add({
              'insert': '\n',
              'attributes': {'code-block': true}
            });
          }
          break;
        case 'blockquote':
          // Cada párrafo de la cita genera su propia línea con blockquote
          final hayParrafos = (node.children ?? [])
              .any((c) => c is md.Element && c.tag == 'p');
          if (hayParrafos) {
            for (final hijo in node.children!) {
              if (hijo is md.Element && hijo.tag == 'p') {
                _processInlineChildren(hijo, deltaOps, null);
                deltaOps.add({
                  'insert': '\n',
                  'attributes': {'blockquote': true}
                });
              } else if (hijo is md.Text) {
                if (hijo.text.trim().isNotEmpty) {
                  deltaOps.add({'insert': hijo.text.trim()});
                  deltaOps.add({
                    'insert': '\n',
                    'attributes': {'blockquote': true}
                  });
                }
              } else {
                _processNode(hijo, deltaOps);
              }
            }
            break;
          }
          _processInlineChildren(node, deltaOps, null);
          deltaOps.add({
            'insert': '\n',
            'attributes': {'blockquote': true}
          });
          break;
        case 'ul':
          _procesarLista(node, deltaOps, false, 0);
          break;
        case 'ol':
          _procesarLista(node, deltaOps, true, 0);
          break;
        case 'a':
          // Enlaces: [text](url) o [text](url "title")
          final href = node.attributes['href'] ?? '';
          final title = node.attributes['title'];
          final linkText = _extractText(node);

          if (linkText.isNotEmpty && href.isNotEmpty) {
            deltaOps.add({
              'insert': linkText,
              'attributes': {
                'link': href,
                if (title != null) 'link_title': title,
              },
            });
          }
          break;
        case 'img':
          // Imágenes: ![alt](url) o ![alt](url "title")
          final src = node.attributes['src'] ?? '';
          final alt = node.attributes['alt'] ?? '';
          final title = node.attributes['title'];

          if (src.isNotEmpty) {
            // Nota: Quill maneja imágenes como embeds
            // Para URLs web, insertamos como imagen simple
            deltaOps.add({
              'insert': {
                'image': src,
              },
            });
            // Metadata adicional (alt y title) se puede guardar en un atributo
            if (alt.isNotEmpty || title != null) {
              // Agregar como comentario en el documento (opcional)
              // Por ahora, solo insertamos la imagen
            }
          }
          break;
        case 'hr':
          // Regla horizontal - temporalmente desactivado hasta crear DividerEmbedBuilder
          // Por ahora, insertar una línea de guiones como texto
          deltaOps.add({'insert': '---'});
          deltaOps.add({'insert': '\n'});
          break;
        case 'table':
          // Procesar tabla generada por el parser de Markdown
          _processTableNode(node, deltaOps);
          break;
        case 'thead':
        case 'tbody':
        case 'tr':
        case 'th':
        case 'td':
          // Estos son procesados por _processTableNode, no individualmente
          break;
        default:
          // Para otros elementos, procesar hijos recursivamente
          if (node.children != null) {
            for (final child in node.children!) {
              _processNode(child, deltaOps);
            }
          }
      }
    } else if (node is md.Text) {
      if (node.text.isNotEmpty) {
        deltaOps.add({'insert': node.text});
      }
    }
  }

  /// Procesa una lista (`ul`/`ol`) respetando el anidamiento: cada nivel
  /// extra añade `indent` al salto de línea del ítem (formato Quill).
  static void _procesarLista(
    md.Element lista,
    List<Map<String, dynamic>> deltaOps,
    bool ordenada,
    int nivel,
  ) {
    for (final child in lista.children ?? <md.Node>[]) {
      if (child is! md.Element) continue;
      if (child.tag == 'ul' || child.tag == 'ol') {
        // Lista anidada colgando directamente de otra lista
        _procesarLista(child, deltaOps, child.tag == 'ol', nivel + 1);
        continue;
      }
      if (child.tag != 'li') continue;

      final propios = <md.Node>[];
      final anidadas = <md.Element>[];
      for (final h in child.children ?? <md.Node>[]) {
        if (h is md.Element && (h.tag == 'ul' || h.tag == 'ol')) {
          anidadas.add(h);
        } else {
          propios.add(h);
        }
      }
      final liPropio = md.Element('li', propios);
      final texto = _extractText(liPropio).trim();

      String tipo = ordenada ? 'ordered' : 'bullet';
      var itemOps = <Map<String, dynamic>>[];
      if (!ordenada && texto.startsWith('[ ]')) {
        tipo = 'unchecked';
        itemOps.add({'insert': texto.substring(3).trim()});
      } else if (!ordenada && (texto.startsWith('[x]') || texto.startsWith('[X]'))) {
        tipo = 'checked';
        itemOps.add({'insert': texto.substring(3).trim()});
      } else {
        _processInlineChildren(liPropio, itemOps, null);
      }
      deltaOps.addAll(itemOps);
      deltaOps.add({
        'insert': '\n',
        'attributes': {'list': tipo, if (nivel > 0) 'indent': nivel},
      });

      for (final sub in anidadas) {
        _procesarLista(sub, deltaOps, sub.tag == 'ol', nivel + 1);
      }
    }
  }

  static void _processInlineChildren(
    md.Element element,
    List<Map<String, dynamic>> deltaOps,
    Map<String, dynamic>? attributes,
  ) {
    if (element.children == null) return;

    for (final child in element.children!) {
      if (child is md.Text) {
        if (child.text.isNotEmpty) {
          if (attributes != null && attributes.isNotEmpty) {
            deltaOps.add({
              'insert': child.text,
              'attributes': attributes,
            });
          } else {
            deltaOps.add({'insert': child.text});
          }
        }
      } else if (child is md.Element) {
        // Manejar enlaces e imágenes que aparecen inline
        if (child.tag == 'a') {
          // Enlace inline
          final href = child.attributes['href'] ?? '';
          final title = child.attributes['title'];
          final linkText = _extractText(child);

          if (linkText.isNotEmpty && href.isNotEmpty) {
            // Combinar atributos del enlace con atributos heredados
            final linkAttributes = {
              ...?attributes,
              'link': href,
              if (title != null) 'link_title': title,
            };
            deltaOps.add({
              'insert': linkText,
              'attributes': linkAttributes,
            });
          }
        } else if (child.tag == 'img') {
          // Imagen inline
          final src = child.attributes['src'] ?? '';
          if (src.isNotEmpty) {
            deltaOps.add({
              'insert': {
                'image': src,
              },
            });
          }
        } else if (child.tag == 'br') {
          // Salto de línea inline
          deltaOps.add({'insert': '\n'});
        } else {
          // Determinar atributos específicos para este elemento
          Map<String, dynamic> newAttributes = {};

          if (child.tag == 'strong' || child.tag == 'b') {
            newAttributes['bold'] = true;
          } else if (child.tag == 'em' || child.tag == 'i') {
            newAttributes['italic'] = true;
          } else if (child.tag == 'u') {
            newAttributes['underline'] = true;
          } else if (child.tag == 'del' || child.tag == 's') {
            newAttributes['strike'] = true;
          } else if (child.tag == 'code') {
            newAttributes['code'] = true;
          } else if (child.tag == 'sup') {
            newAttributes['script'] = 'super';
          } else if (child.tag == 'sub') {
            newAttributes['script'] = 'sub';
          } else if (child.tag == 'mark') {
            newAttributes['highlight'] = true;
          }

          // Combinar con atributos heredados solo si hay atributos nuevos
          Map<String, dynamic>? combinedAttributes;
          if (newAttributes.isNotEmpty) {
            combinedAttributes = {...?attributes, ...newAttributes};
          } else {
            combinedAttributes = attributes;
          }

          _processInlineChildren(child, deltaOps, combinedAttributes);
        }
      }
    }
  }

  static String _extractText(md.Node node) {
    if (node is md.Text) {
      return node.text;
    } else if (node is md.Element) {
      return (node.children ?? []).map(_extractText).join();
    }
    return '';
  }

  /// Procesa un nodo de tabla del parser de Markdown
  static void _processTableNode(md.Element tableNode, List<Map<String, dynamic>> deltaOps) {
    try {
      final rows = <List<String>>[];

      // Buscar thead y tbody
      for (final child in tableNode.children ?? []) {
        if (child is md.Element) {
          if (child.tag == 'thead' || child.tag == 'tbody') {
            // Procesar filas (tr)
            for (final rowNode in child.children ?? []) {
              if (rowNode is md.Element && rowNode.tag == 'tr') {
                final row = <String>[];

                // Procesar celdas (th o td)
                for (final cellNode in rowNode.children ?? []) {
                  if (cellNode is md.Element && (cellNode.tag == 'th' || cellNode.tag == 'td')) {
                    final cellText = _extractText(cellNode);
                    row.add(cellText);
                  }
                }

                if (row.isNotEmpty) {
                  rows.add(row);
                }
              }
            }
          }
        }
      }

      if (rows.isEmpty) {
        return;
      }

      // Determinar número de columnas (máximo de todas las filas)
      final columns = rows.map((row) => row.length).reduce((a, b) => a > b ? a : b);

      // Normalizar todas las filas para que tengan el mismo número de columnas
      for (final row in rows) {
        while (row.length < columns) {
          row.add('');
        }
      }

      // Crear JSON de tabla
      final tableData = {
        'rows': rows.length,
        'columns': columns,
        'cells': rows,
      };

      // Insertar embed de tabla
      deltaOps.add({
        'insert': {
          'table': jsonEncode(tableData),
        }
      });
      deltaOps.add({'insert': '\n'});
    } catch (e) {
      // En caso de error, ignorar la tabla
      print('⚠️ Error procesando tabla: $e');
    }
  }

  /// Detecta si un texto parece ser Markdown
  /// Basado en las reglas completas de sintaxis Markdown
  static bool looksLikeMarkdown(String text) {
    // Si el texto es muy corto, probablemente no sea Markdown
    if (text.trim().length < 3) return false;

    // Heurística completa para detectar Markdown
    final markdownPatterns = [
      // ENCABEZADOS
      RegExp(r'^#{1,6}\s', multiLine: true),  // Headers con almohadillas
      RegExp(r'^.+\n=+\s*$', multiLine: true), // Header 1 con subrayado
      RegExp(r'^.+\n-+\s*$', multiLine: true), // Header 2 con subrayado

      // ÉNFASIS
      RegExp(r'\*\*.+?\*\*'), // Bold con asteriscos
      RegExp(r'__.+?__'),     // Bold con guiones bajos
      RegExp(r'(?<!\*)\*(?!\*)[\w\s]+?\*(?!\*)'), // Italic con asterisco
      RegExp(r'(?<!_)_(?!_)[\w\s]+?_(?!_)'),     // Italic con guión bajo
      RegExp(r'\*\*\*.+?\*\*\*'), // Bold + Italic
      RegExp(r'___.+?___'),     // Bold + Italic alternativo

      // LISTAS
      RegExp(r'^\s*[-*+]\s', multiLine: true), // Listas desordenadas
      RegExp(r'^\s*\d+\.\s', multiLine: true), // Listas numeradas
      RegExp(r'^\s{4,}[-*+]\s', multiLine: true), // Listas anidadas (4+ espacios)
      RegExp(r'^\s*-\s\[[ xX]\]', multiLine: true), // Task lists

      RegExp(r'^\s*[•◦▪‣∙●]\s', multiLine: true), // Viñetas tipográficas
      RegExp(r'^\s*[–—]\s.+\n\s*[–—]\s', multiLine: true), // Racha de guiones largos

      // CITAS
      RegExp(r'^\s*>\s', multiLine: true),     // Blockquotes
      RegExp(r'^\s*>>\s', multiLine: true),    // Blockquotes anidados

      // CÓDIGO
      RegExp(r'`[^`]+`'),     // Inline code
      RegExp(r'```'),         // Code blocks con triple backtick
      RegExp(r'~~~'),         // Code blocks con triple tilde
      RegExp(r'^    \S', multiLine: true), // Code blocks con 4 espacios

      // ENLACES E IMÁGENES
      RegExp(r'\[.+?\]\(.+?\)'), // Links inline
      RegExp(r'\[.+?\]\[.+?\]'), // Links por referencia
      RegExp(r'!\[.+?\]\(.+?\)'), // Imágenes inline
      RegExp(r'!\[.+?\]\[.+?\]'), // Imágenes por referencia
      RegExp(r'<https?://.+?>'), // Links automáticos

      // REGLAS HORIZONTALES
      RegExp(r'^[\s]*[-*_]{3,}[\s]*$', multiLine: true), // ---, ***, ___

      // TABLAS
      RegExp(r'^\|.+\|$', multiLine: true), // Líneas con pipes
      RegExp(r'^\|[\s\-:]+\|$', multiLine: true), // Separadores de tabla

      // FORMATOS EXTENDIDOS
      RegExp(r'==.+?=='),     // Resaltado
      RegExp(r'\^.+?\^'),     // Superíndice
      RegExp(r'(?<!~)~[^~]+~(?!~)'), // Subíndice
      RegExp(r'~~.+?~~'),     // Tachado

      // SALTOS DE LÍNEA (2 espacios + newline)
      RegExp(r'  \n'),
    ];

    // Contar cuántos patrones coinciden
    int matchCount = 0;
    for (final pattern in markdownPatterns) {
      if (pattern.hasMatch(text)) {
        matchCount++;
        // Si encuentra 2 o más patrones, es muy probable que sea Markdown
        if (matchCount >= 2) return true;
      }
    }

    // Si encuentra al menos 1 patrón y el texto tiene múltiples líneas,
    // probablemente sea Markdown
    if (matchCount >= 1 && text.contains('\n')) return true;

    return false;
  }
}
