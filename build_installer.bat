@echo off
REM ============================================
REM Script para crear instalador de Sinapsis
REM Requiere Inno Setup instalado
REM ============================================

echo.
echo ==========================================
echo   SINAPSIS - Creador de Instalador
echo ==========================================
echo.

REM Verificar que el build existe
if not exist "build\windows\x64\runner\Release\sinapsis.exe" (
    echo [ERROR] No se encontro el ejecutable compilado
    echo Primero ejecuta: build_windows.bat
    pause
    exit /b 1
)

REM Buscar Inno Setup
set ISCC=""
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    set ISCC="%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
) else if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
    set ISCC="%ProgramFiles%\Inno Setup 6\ISCC.exe"
)

if %ISCC%=="" (
    echo [ERROR] Inno Setup no encontrado
    echo.
    echo Descarga Inno Setup desde: https://jrsoftware.org/isdl.php
    echo.
    pause
    exit /b 1
)

REM Crear directorio de salida
if not exist "build\installer" mkdir "build\installer"

REM Compilar instalador
echo [INFO] Creando instalador...
%ISCC% "installer\sinapsis_installer.iss"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] No se pudo crear el instalador
    pause
    exit /b 1
)

echo.
echo ==========================================
echo   INSTALADOR CREADO EXITOSAMENTE!
echo ==========================================
echo.
echo El instalador se encuentra en:
echo   build\installer\Sinapsis_Setup_v1.0.0.exe
echo.
pause
