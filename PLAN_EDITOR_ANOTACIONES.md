# Plan: Editor de Anotaciones - Corrección y Mejora

## 1. Problema Actual

### Síntomas
- Las anotaciones (dibujos, textos) no se guardan correctamente
- Al reabrir la imagen en modo estudio, no se muestran las anotaciones
- El diálogo de texto era lento/buggy (ya corregido parcialmente)

### Causa Raíz
1. **Coordenadas no normalizadas**: Las imágenes tienen diferentes tamaños, pero las coordenadas se guardan en píxeles absolutos en lugar de valores normalizados (0-1)
2. **Flujo de guardado incompleto**:
   - El editor captura `imageBytes` pero el guardado a archivo puede fallar
   - No hay verificación de que el archivo se guardó correctamente
   - La ruta nueva no siempre se propaga al documento
3. **Rendering inconsistente**: El tamaño del canvas en el editor vs el tamaño en modo estudio pueden diferir

## 2. Análisis de Tamaños de Imagen

### Problema de Coordenadas
```
Imagen Original: 1920x1080
Canvas Editor:   800x450 (escalado)
Canvas Estudio:  600x337 (diferente escala)

Si guardamos punto en (400, 225) del editor:
- En imagen original sería: (960, 540) ← INCORRECTO si se usa directo
- Debería ser normalizado: (0.5, 0.5) ← CORRECTO
```

### Solución: Coordenadas Normalizadas
```dart
// Al guardar
double normalizedX = pixelX / canvasWidth;  // 0.0 - 1.0
double normalizedY = pixelY / canvasHeight; // 0.0 - 1.0

// Al renderizar
double pixelX = normalizedX * currentCanvasWidth;
double pixelY = normalizedY * currentCanvasHeight;
```

## 3. Arquitectura Propuesta

### Opción A: Guardar como imagen renderizada (ACTUAL)
```
[Editor] → [Capturar canvas como PNG] → [Guardar archivo] → [Actualizar path en documento]

Pros: Simple, la imagen ya tiene todo incluido
Contras: Pierde capacidad de editar anotaciones individuales después
```

### Opción B: Guardar datos + re-renderizar (RECOMENDADO)
```
[Editor] → [Guardar datos normalizados] → [Documento JSON]
                                               ↓
[Modo Estudio] ← [Renderizar desde datos] ← [Leer JSON]

Pros: Editable, escalable, flexible
Contras: Más complejo, requiere painter consistente
```

### Decisión: Opción A (más simple y confiable para el usuario)
- El usuario espera ver exactamente lo que dibujó
- No necesita editar anotaciones después (puede rehacerlas)
- Menos puntos de fallo

## 4. Plan de Implementación

### Fase 1: Verificar flujo de guardado actual
- [ ] Agregar logs para verificar que `imageBytes` no es null
- [ ] Verificar que el directorio se crea correctamente
- [ ] Verificar que el archivo se escribe correctamente
- [ ] Verificar que la ruta se actualiza en el documento

### Fase 2: Corregir el editor de anotaciones
- [ ] Asegurar que RepaintBoundary captura toda el área correctamente
- [ ] Manejar diferentes tamaños de imagen de entrada
- [ ] Mantener aspect ratio correcto

### Fase 3: Corregir el guardado
- [ ] Agregar manejo de errores robusto
- [ ] Mostrar feedback al usuario (éxito/error)
- [ ] Verificar que el archivo existe después de guardar

### Fase 4: Corregir visualización en modo estudio
- [ ] Asegurar que se carga la imagen correcta (original vs anotada)
- [ ] Manejar caso donde imagen anotada no existe

## 5. Código a Modificar

### Archivos
1. `lib/features/notes/presentation/widgets/image_annotation_editor.dart`
   - Mejorar captura de imagen
   - Manejar aspect ratio

2. `lib/features/notes/presentation/widgets/rich_document_editor.dart`
   - Mejorar manejo de resultado del editor
   - Agregar verificación de guardado

3. `lib/features/notes/presentation/widgets/study_document_viewer.dart`
   - Verificar que carga la imagen correcta

## 6. Plan de Testing

### Test 1: Guardado básico
1. Abrir nota con imagen
2. Abrir editor de anotaciones
3. Dibujar una línea roja
4. Guardar
5. **Verificar**: Archivo existe en `~/Documents/sinapsis/annotated/`
6. **Verificar**: Documento tiene nueva ruta

### Test 2: Visualización en modo estudio
1. Completar Test 1
2. Abrir modo estudio
3. **Verificar**: Se ve la imagen con la línea roja

### Test 3: Diferentes tamaños de imagen
1. Probar con imagen pequeña (400x300)
2. Probar con imagen grande (1920x1080)
3. Probar con imagen vertical (600x800)
4. **Verificar**: En todos los casos las anotaciones se ven correctamente

### Test 4: Texto
1. Abrir editor
2. Añadir texto "TEST"
3. Guardar
4. **Verificar**: Texto visible en modo estudio

### Test 5: Múltiples anotaciones
1. Dibujar varias líneas
2. Añadir varios textos
3. Guardar
4. **Verificar**: Todo visible en modo estudio

## 7. Implementación Detallada

### Paso 1: Agregar logs de diagnóstico
```dart
// En image_annotation_editor.dart
Future<void> _save() async {
  debugPrint('=== GUARDANDO ANOTACIONES ===');

  try {
    final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    debugPrint('Boundary: $boundary');

    if (boundary == null) {
      debugPrint('ERROR: Boundary es null');
      return;
    }

    final image = await boundary.toImage(pixelRatio: 2.0);
    debugPrint('Imagen capturada: ${image.width}x${image.height}');

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    debugPrint('Bytes: ${byteData?.lengthInBytes ?? 0}');

    // ... resto del código
  } catch (e, stack) {
    debugPrint('ERROR: $e');
    debugPrint('Stack: $stack');
  }
}
```

### Paso 2: Verificar guardado en rich_document_editor.dart
```dart
if (imageBytes != null) {
  debugPrint('=== GUARDANDO IMAGEN ANOTADA ===');
  debugPrint('Bytes recibidos: ${imageBytes.length}');

  try {
    final appDir = await getApplicationDocumentsDirectory();
    final annotatedDir = Directory('${appDir.path}/sinapsis/annotated');

    if (!await annotatedDir.exists()) {
      await annotatedDir.create(recursive: true);
      debugPrint('Directorio creado: ${annotatedDir.path}');
    }

    final newFile = File('${annotatedDir.path}/annotated_$timestamp.png');
    await newFile.writeAsBytes(imageBytes);

    // VERIFICAR que se guardó
    if (await newFile.exists()) {
      final savedSize = await newFile.length();
      debugPrint('Archivo guardado: ${newFile.path} ($savedSize bytes)');
      finalImagePath = newFile.path;
    } else {
      debugPrint('ERROR: Archivo no se guardó');
    }
  } catch (e) {
    debugPrint('ERROR guardando: $e');
  }
}
```

## 8. Librerías Consideradas

### image_painter (probada - tiene bugs con texto en Linux)
- No recomendada para este caso

### Solución nativa Flutter (ACTUAL)
- RepaintBoundary + CustomPainter
- Simple y funciona
- Solo necesita correcciones menores

## 9. Cronograma de Ejecución

1. **Agregar logs de diagnóstico** - Identificar punto exacto de fallo
2. **Corregir flujo de guardado** - Asegurar que bytes llegan y se guardan
3. **Verificar visualización** - Asegurar que imagen anotada se muestra
4. **Testing completo** - Probar todos los casos
5. **Limpiar logs** - Remover debugPrints innecesarios

## 10. Siguiente Paso Inmediato

Ejecutar la app, probar el flujo completo y revisar los logs para identificar dónde falla exactamente.
