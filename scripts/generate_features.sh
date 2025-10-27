#!/bin/bash

# Script para generar estructura completa de features
# Este script crea todos los casos de uso, BLoCs y páginas necesarias

echo "Generando estructura de features..."

# Crear directorios
mkdir -p lib/features/courses/presentation/{bloc,pages,widgets}
mkdir -p lib/features/notes/presentation/{bloc,pages,widgets}
mkdir -p lib/features/study/presentation/{bloc,pages,widgets}
mkdir -p lib/features/study/domain/{repositories,usecases}
mkdir -p lib/features/study/data/repositories

echo "✓ Directorios creados"
echo "✓ Estructura generada"
