#!/bin/bash

echo "🔧 Generando código con build_runner..."
flutter pub run build_runner build --delete-conflicting-outputs

if [ $? -eq 0 ]; then
    echo "✅ Código generado exitosamente"
else
    echo "❌ Error al generar código"
    exit 1
fi
