# Instrucciones para Subir a GitHub

## ✅ YA COMPLETADO

- ✅ Repositorio Git inicializado
- ✅ 162 archivos agregados
- ✅ Commit inicial creado (24,466 líneas)
- ✅ Rama principal: `main`

---

## 📋 SIGUIENTE PASO: Crear Repositorio en GitHub

### Opción 1: Crear repositorio en GitHub.com (Recomendado)

1. **Ve a GitHub:**
   - Abre tu navegador
   - Ve a: https://github.com/new

2. **Configura el repositorio:**
   ```
   Nombre del repositorio: sinapsis
   Descripción: Sistema Integral de Estudio y Repaso Activo con SRS y Pomodoro
   Visibilidad: Public (para usar GitHub Actions gratis)

   ❌ NO marques: "Add a README file"
   ❌ NO marques: "Add .gitignore"
   ❌ NO marques: "Choose a license"
   ```

3. **Click en "Create repository"**

4. **Copia la URL del repositorio** que aparece en la página
   - Debería verse algo como: `https://github.com/TU-USUARIO/sinapsis.git`

---

## 🚀 HACER PUSH A GITHUB

### Si ya creaste el repositorio en GitHub:

Ejecuta estos comandos en la terminal:

```bash
# 1. Agregar el repositorio remoto (reemplaza TU-USUARIO con tu usuario de GitHub)
git remote add origin https://github.com/TU-USUARIO/sinapsis.git

# 2. Verificar que se agregó correctamente
git remote -v

# 3. Hacer push del código
git push -u origin main
```

**Ejemplo:**
Si tu usuario es "juanperez", el comando sería:
```bash
git remote add origin https://github.com/juanperez/sinapsis.git
git push -u origin main
```

---

## 🔐 Autenticación

Cuando hagas `git push`, GitHub te pedirá credenciales:

### Opción A: Personal Access Token (Recomendado)

1. **Genera un token:**
   - Ve a: https://github.com/settings/tokens
   - Click en "Generate new token (classic)"
   - Selecciona: `repo` (Full control of private repositories)
   - Click "Generate token"
   - **COPIA EL TOKEN** (solo se muestra una vez)

2. **Usa el token al hacer push:**
   ```
   Username: tu-usuario-github
   Password: [PEGA EL TOKEN AQUÍ]
   ```

### Opción B: GitHub CLI (Alternativa)

```bash
# Instalar GitHub CLI
sudo apt install gh

# Autenticar
gh auth login

# Hacer push
git push -u origin main
```

---

## ⚡ Verificar que Funcionó

Después de hacer push:

1. **Ve a tu repositorio en GitHub:**
   `https://github.com/TU-USUARIO/sinapsis`

2. **Verifica:**
   - ✅ Ves todos tus archivos
   - ✅ El README.md se muestra correctamente
   - ✅ Hay 162 archivos

3. **Click en la pestaña "Actions":**
   - Deberías ver "Build Windows Release" ejecutándose
   - Espera ~10-15 minutos
   - Cuando termine, descarga el artifact

---

## 📦 Descargar el Build de Windows

Una vez que GitHub Actions termine:

1. **Ve a la pestaña "Actions"**
2. **Click en el workflow más reciente** (con ✅ verde)
3. **Scroll hasta "Artifacts"**
4. **Descarga "sinapsis-windows-release.zip"**
5. **¡Listo! Ese es tu ejecutable para Windows**

---

## 🐛 Solución de Problemas

### Error: "remote origin already exists"
```bash
git remote remove origin
git remote add origin https://github.com/TU-USUARIO/sinapsis.git
```

### Error: "authentication failed"
- Asegúrate de usar un Personal Access Token, no tu contraseña
- Genera uno nuevo en: https://github.com/settings/tokens

### Error: "! [rejected] main -> main (fetch first)"
```bash
git pull origin main --allow-unrelated-histories
git push -u origin main
```

---

## 📝 Comandos Completos (Copia y Pega)

```bash
# Reemplaza TU-USUARIO con tu usuario real de GitHub
export GITHUB_USER="TU-USUARIO"

# Agregar remote
git remote add origin https://github.com/$GITHUB_USER/sinapsis.git

# Push
git push -u origin main
```

---

## ✨ Después del Push

**GitHub Actions compilará automáticamente:**
- ✅ Windows ejecutable (.exe)
- ✅ Creará un ZIP listo para distribuir
- ✅ Lo subirá como artifact descargable

**Para futuras actualizaciones:**
```bash
git add .
git commit -m "Descripción de los cambios"
git push
```

---

## 🎯 Resumen Visual

```
┌─────────────────┐
│  Código Local   │ ← YA ESTÁS AQUÍ (Commit hecho ✅)
└────────┬────────┘
         │
         │ git remote add origin https://...
         │ git push -u origin main
         ▼
┌─────────────────┐
│     GitHub      │ ← PRÓXIMO PASO
└────────┬────────┘
         │
         │ GitHub Actions se ejecuta automáticamente
         ▼
┌─────────────────┐
│  Windows .exe   │ ← DESCARGA EL ARTIFACT
└─────────────────┘
```

---

**¿Necesitas ayuda?**
- ¿No tienes cuenta de GitHub? Créala gratis en: https://github.com/signup
- ¿Primera vez usando Git? Sigue paso a paso esta guía
- ¿Problemas con autenticación? Usa Personal Access Token

---

**Última actualización:** 2025-10-27
