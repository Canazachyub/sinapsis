part of 'sync_bloc.dart';

abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

/// Sincronización completa pedida por el usuario ("Sincronizar ahora"):
/// descarga de Supabase y sube todas las notas y cursos locales.
class SyncStarted extends SyncEvent {
  const SyncStarted();
}

/// Solo descargar cambios remotos (sincronización heredada con Drift).
class SyncPullRequested extends SyncEvent {
  const SyncPullRequested();
}

/// Solo subir cambios locales (sincronización heredada con Drift).
class SyncPushRequested extends SyncEvent {
  const SyncPushRequested();
}

/// Sincronización automática (al arrancar o tras iniciar sesión).
/// Es silenciosa: no muestra indicadores de carga.
class SyncAutoStarted extends SyncEvent {
  const SyncAutoStarted();
}
