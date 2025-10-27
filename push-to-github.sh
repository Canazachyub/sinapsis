#!/bin/bash

# Script para hacer push a GitHub
# Uso: ./push-to-github.sh TU-USUARIO-GITHUB

if [ -z "$1" ]; then
    echo "❌ Error: Debes proporcionar tu usuario de GitHub"
    echo ""
    echo "Uso: ./push-to-github.sh TU-USUARIO"
    echo "Ejemplo: ./push-to-github.sh juanperez"
    echo ""
    exit 1
fi

GITHUB_USER=$1
REPO_URL="https://github.com/$GITHUB_USER/sinapsis.git"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║          SUBIENDO SINAPSIS A GITHUB                       ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Usuario GitHub: $GITHUB_USER"
echo "URL Repositorio: $REPO_URL"
echo ""

# Verificar si ya existe un remote
if git remote get-url origin &>/dev/null; then
    echo "⚠️  Remote 'origin' ya existe. Actualizando..."
    git remote set-url origin $REPO_URL
else
    echo "➕ Agregando remote 'origin'..."
    git remote add origin $REPO_URL
fi

echo ""
echo "📡 Verificando remote..."
git remote -v
echo ""

echo "🚀 Haciendo push a GitHub..."
echo ""
echo "Nota: GitHub te pedirá autenticación."
echo "      Usa tu Personal Access Token como password."
echo "      Genera uno en: https://github.com/settings/tokens"
echo ""

# Hacer push
if git push -u origin main; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              ✅ PUSH EXITOSO                              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "✨ Tu código está en GitHub!"
    echo ""
    echo "🔗 Repositorio: https://github.com/$GITHUB_USER/sinapsis"
    echo "🔨 Actions: https://github.com/$GITHUB_USER/sinapsis/actions"
    echo ""
    echo "📦 GitHub Actions compilará Windows automáticamente"
    echo "   Ve a la pestaña Actions para ver el progreso"
    echo "   Descarga el artifact cuando termine (~10-15 min)"
    echo ""
    echo "🎉 ¡Todo listo!"
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              ❌ ERROR EN PUSH                             ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Posibles causas:"
    echo "1. El repositorio no existe en GitHub"
    echo "   → Créalo en: https://github.com/new"
    echo ""
    echo "2. Problemas de autenticación"
    echo "   → Usa un Personal Access Token"
    echo "   → Genéralo en: https://github.com/settings/tokens"
    echo ""
    echo "3. El repositorio ya tiene contenido"
    echo "   → Ejecuta: git pull origin main --allow-unrelated-histories"
    echo "   → Luego: git push -u origin main"
    echo ""
    exit 1
fi
