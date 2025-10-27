#!/bin/bash

echo "🚀 Configurando Sinapsis..."

# Verificar Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter no está instalado. Por favor instala Flutter primero."
    exit 1
fi

echo "✅ Flutter encontrado"

# Instalar dependencias
echo "📦 Instalando dependencias..."
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ Error al instalar dependencias"
    exit 1
fi

echo "✅ Dependencias instaladas"

# Verificar archivo .env
if [ ! -f ".env" ]; then
    echo "⚠️  Archivo .env no encontrado"
    echo "📝 Creando .env desde .env.example..."
    cp .env.example .env
    echo "⚠️  Por favor configura tus variables de entorno en .env"
fi

# Generar código
echo "🔧 Generando código..."
flutter pub run build_runner build --delete-conflicting-outputs

if [ $? -ne 0 ]; then
    echo "❌ Error al generar código"
    exit 1
fi

echo "✅ Código generado"

echo ""
echo "🎉 ¡Configuración completada!"
echo ""
echo "📝 Próximos pasos:"
echo "1. Configura tu archivo .env con las credenciales de Supabase"
echo "2. Ejecuta las migraciones SQL en tu proyecto de Supabase"
echo "3. Ejecuta: flutter run -d linux (o android/chrome)"
echo ""
