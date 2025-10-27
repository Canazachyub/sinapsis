# Modo Offline - Sinapsis

Sinapsis puede funcionar 100% offline sin necesidad de Supabase.

## ¿Cómo Funciona?

La aplicación detecta automáticamente si debe usar **modo local** o **modo Supabase**:

### Modo LOCAL/OFFLINE (Recomendado para uso personal)

Se activa automáticamente cuando:
- `APP_ENV=demo` en el `.env`
- O la URL de Supabase contiene `'tu-proyecto'` o `'placeholder'`

**Características:**
- ✅ Autenticación local (SharedPreferences)
- ✅ Base de datos SQLite local (Drift)
- ✅ Todo funciona sin internet
- ✅ Sin necesidad de cuenta Supabase
- ✅ Datos privados en tu PC

### Modo SUPABASE (Para sincronización multi-dispositivo)

Se activa cuando tienes credenciales reales de Supabase.

**Características:**
- ✅ Autenticación con Supabase
- ✅ Base de datos local + sincronización
- ✅ Datos compartidos entre dispositivos
- ⚠️ Requiere internet para sincronizar

## Configuración

### Para Modo Offline (Por Defecto)

**Archivo `.env`:**
```env
# Modo Offline - No se conecta a Supabase
SUPABASE_URL=https://placeholder.supabase.co
SUPABASE_ANON_KEY=placeholder-anon-key
APP_ENV=demo
```

### Para Modo Supabase

1. Crea cuenta en [supabase.com](https://supabase.com)
2. Crea un nuevo proyecto
3. Copia las credenciales

**Archivo `.env`:**
```env
# Modo Supabase - Sincronización habilitada
SUPABASE_URL=https://tu-proyecto-real.supabase.co
SUPABASE_ANON_KEY=tu-clave-real-aqui
APP_ENV=production
```

## Almacenamiento de Datos

### Modo Offline

**Windows:**
```
C:\Users\TU_USUARIO\AppData\Roaming\sinapsis\
├── database.db           ← Base de datos SQLite
├── flutter.preferences   ← Autenticación y configuración
```

**Linux:**
```
~/.local/share/sinapsis/
├── database.db
├── flutter.preferences
```

**Android:**
```
/data/data/com.sinapsis.sinapsis/
├── databases/database.db
├── shared_prefs/
```

### Modo Supabase

- **Local:** Igual que modo offline
- **Cloud:** Datos sincronizados en Supabase PostgreSQL

## Autenticación

### Modo Offline

- **Registro:** Guarda usuarios en SharedPreferences localmente
- **Login:** Verifica contra datos locales
- **Contraseñas:** Guardadas en texto plano (solo local, sin riesgo de red)
- **Sesión:** Persistente en dispositivo

### Modo Supabase

- **Registro:** Crea usuario en Supabase Auth
- **Login:** Verifica con servidor Supabase
- **Contraseñas:** Hasheadas por Supabase
- **Sesión:** Token JWT con refresh automático

## Ventajas y Desventajas

| Característica | Offline | Supabase |
|---|---|---|
| **Velocidad** | ⚡ Instantáneo | 🌐 Depende de red |
| **Privacidad** | 🔒 100% Local | ☁️ En la nube |
| **Internet** | ❌ No necesario | ✅ Necesario |
| **Multi-dispositivo** | ❌ No sincroniza | ✅ Sincroniza |
| **Backup** | ⚠️ Manual | ✅ Automático |
| **Costo** | 💰 Gratis | 💰 Gratis (límites) |

## Migración de Datos

### De Offline a Supabase

1. Exporta tu base de datos SQLite
2. Configura Supabase en `.env`
3. Importa datos manualmente (próximamente automático)

### De Supabase a Offline

1. Descarga tus datos de Supabase
2. Cambia `.env` a modo offline
3. La app usará solo datos locales

## Desarrollo

### Para Desarrollo Local

Usa modo offline para desarrollo más rápido:

```bash
# .env
APP_ENV=demo
SUPABASE_URL=https://placeholder.supabase.co
```

### Para Testing con Supabase

```bash
# .env
APP_ENV=production
SUPABASE_URL=https://tu-proyecto-test.supabase.co
SUPABASE_ANON_KEY=tu-clave-test
```

## CI/CD (GitHub Actions)

El workflow de Windows usa modo offline automáticamente:

```yaml
- name: Create .env file
  run: |
    echo "SUPABASE_URL=https://placeholder.supabase.co" > .env
    echo "SUPABASE_ANON_KEY=placeholder-anon-key" >> .env
    echo "APP_ENV=demo" >> .env
```

## FAQ

### ¿Puedo cambiar entre modos?

Sí, solo cambia el `.env` y reinicia la app.

### ¿Se pierden datos al cambiar?

No, los datos locales se mantienen. Pero no se sincronizarán automáticamente.

### ¿Puedo usar Supabase solo para backup?

Sí, usa modo offline y exporta/importa manualmente.

### ¿El modo offline es seguro?

Sí, tus datos nunca salen de tu dispositivo. Es más privado que Supabase.

### ¿Puedo compartir datos entre PCs en modo offline?

No directamente. Necesitas exportar/importar o usar Supabase.

## Código Relevante

**Detección de modo:** [lib/injection_container.dart](lib/injection_container.dart) líneas 108-110

**Autenticación offline:** [lib/features/auth/data/datasources/auth_remote_datasource_mock.dart](lib/features/auth/data/datasources/auth_remote_datasource_mock.dart)

**Autenticación Supabase:** [lib/features/auth/data/datasources/auth_remote_datasource.dart](lib/features/auth/data/datasources/auth_remote_datasource.dart)

---

**Última actualización:** 2025-10-27
