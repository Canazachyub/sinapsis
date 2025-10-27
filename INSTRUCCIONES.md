# Instrucciones para Ejecutar Sinapsis

## Paso 1: Generar código con build_runner

Antes de ejecutar la aplicación, necesitas generar los archivos `.g.dart` y `.freezed.dart`:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

O si prefieres modo watch (regenera automáticamente al hacer cambios):

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Paso 2: Configurar Supabase

1. Crea una cuenta en [Supabase](https://supabase.com)
2. Crea un nuevo proyecto
3. Ve a `Settings` > `API` y copia:
   - `Project URL` (SUPABASE_URL)
   - `anon public` key (SUPABASE_ANON_KEY)

4. Abre el archivo `.env` y completa:
```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-anon-key-aqui
```

5. Ejecuta las migraciones SQL:
   - Ve a tu proyecto en Supabase
   - Abre el editor SQL (`SQL Editor`)
   - Copia el contenido de `supabase/migrations/00001_initial_schema.sql`
   - Pégalo y ejecútalo

## Paso 3: Ejecutar la aplicación

### Linux Desktop
```bash
flutter run -d linux
```

### Android
```bash
flutter run -d android
```

### Web
```bash
flutter run -d chrome
```

## Solución de Problemas

### Error: "Variable de entorno no encontrada"
- Verifica que el archivo `.env` existe en la raíz del proyecto
- Verifica que tiene las variables SUPABASE_URL y SUPABASE_ANON_KEY configuradas

### Error: "Missing generated files"
- Ejecuta: `flutter pub run build_runner build --delete-conflicting-outputs`
- Espera a que termine la generación de código

### Error de compilación en Linux
Asegúrate de tener las dependencias instaladas:
```bash
# Ubuntu/Debian
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

# Fedora
sudo dnf install clang cmake ninja-build gtk3-devel

# Arch
sudo pacman -S clang cmake ninja gtk3
```

## Características Implementadas

✅ Autenticación con email/password
✅ Página de login
✅ Página de registro
✅ Dashboard básico
✅ Tema claro/oscuro
✅ Arquitectura Clean Architecture
✅ Estado con BLoC
✅ Base de datos local con Drift
✅ Sincronización con Supabase

## Próximos Pasos

- Implementar gestión de cursos
- Implementar gestión de notas (Flashcards, Cloze, etc.)
- Implementar modo de estudio
- Implementar estadísticas
- Implementar sincronización offline
