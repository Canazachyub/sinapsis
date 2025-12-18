@echo off
REM ============================================
REM Script de compilacion para Sinapsis Windows
REM ============================================

echo.
echo ==========================================
echo   SINAPSIS - Compilador para Windows
echo ==========================================
echo.

REM Verificar que Flutter este instalado
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter no esta instalado o no esta en el PATH
    echo Por favor instala Flutter desde: https://flutter.dev/docs/get-started/install/windows
    pause
    exit /b 1
)

REM Verificar version de Flutter
echo [INFO] Verificando Flutter...
flutter --version

REM Limpiar builds anteriores
echo.
echo [INFO] Limpiando builds anteriores...
flutter clean

REM Obtener dependencias
echo.
echo [INFO] Obteniendo dependencias...
flutter pub get

REM Generar codigo (Drift, Freezed, etc.)
echo.
echo [INFO] Generando codigo...
dart run build_runner build --delete-conflicting-outputs

REM Crear archivo .env si no existe
if not exist ".env" (
    echo [INFO] Creando archivo .env...
    echo # Configuracion de Sinapsis > .env
    echo APP_ENV=demo >> .env
    echo SUPABASE_URL=https://demo.supabase.co >> .env
    echo SUPABASE_ANON_KEY=demo-key >> .env
)

REM Compilar para Windows en modo release
echo.
echo [INFO] Compilando para Windows (Release)...
flutter build windows --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] La compilacion fallo
    pause
    exit /b 1
)

echo.
echo ==========================================
echo   COMPILACION EXITOSA!
echo ==========================================
echo.
echo El ejecutable se encuentra en:
echo   build\windows\x64\runner\Release\sinapsis.exe
echo.
echo Para crear un instalador, ejecuta:
echo   build_installer.bat
echo.
pause
