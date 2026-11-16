import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/network_info.dart';
import '../../../../core/services/supabase_sync_helper.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../injection_container.dart';
import '../../../courses/data/datasources/courses_local_datasource.dart';
import '../../../notes/data/datasources/notes_local_datasource.dart';

part 'sync_event.dart';
part 'sync_state.dart';

/// Foto del estado de la conexión con Supabase, para mostrarla en el perfil.
class InfoSincronizacion {
  /// Hay URL y clave reales de Supabase en `.env`.
  final bool configurado;

  /// Email de la sesión de Supabase (null = sin sesión).
  final String? emailSesion;

  /// Última sincronización correcta registrada.
  final DateTime? ultimoSync;

  /// Último error registrado (se borra tras un sync correcto).
  final String? ultimoError;

  /// Momento del último error.
  final DateTime? ultimoErrorEn;

  const InfoSincronizacion({
    required this.configurado,
    this.emailSesion,
    this.ultimoSync,
    this.ultimoError,
    this.ultimoErrorEn,
  });

  bool get conSesion => emailSesion != null;
}

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  /// Sincronización heredada (tablas Drift). Solo para pull/push sueltos.
  final SyncService syncService;
  final NetworkInfo networkInfo;

  static const _kUltimoSync = 'ULTIMO_SYNC_SUPABASE';
  static const _kUltimoError = 'ULTIMO_ERROR_SYNC';
  static const _kUltimoErrorEn = 'ULTIMO_ERROR_SYNC_EN';

  SyncBloc({
    required this.syncService,
    required this.networkInfo,
  }) : super(SyncInitial()) {
    on<SyncStarted>(_onSyncStarted);
    on<SyncPullRequested>(_onSyncPullRequested);
    on<SyncPushRequested>(_onSyncPushRequested);
    on<SyncAutoStarted>(_onSyncAutoStarted);
  }

  // ------------------------------------------------------------ estado

  static SharedPreferences? get _prefs =>
      sl.isRegistered<SharedPreferences>() ? sl<SharedPreferences>() : null;

  static SupabaseClient? get _cliente =>
      sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null;

  /// `true` si `.env` trae una URL y clave reales (no las de demostración).
  static bool get supabaseConfigurado {
    try {
      final url = dotenv.env['SUPABASE_URL'] ?? '';
      final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      return url.isNotEmpty &&
          key.isNotEmpty &&
          !url.contains('tu-proyecto') &&
          !url.contains('placeholder');
    } catch (_) {
      return false;
    }
  }

  /// Estado actual de configuración, sesión y últimos resultados.
  static InfoSincronizacion info() {
    final prefs = _prefs;
    String? email;
    try {
      final usuario = _cliente?.auth.currentUser;
      if (usuario != null) email = usuario.email ?? usuario.id;
    } catch (_) {}
    DateTime? fecha(String k) {
      final v = prefs?.getString(k);
      return v == null ? null : DateTime.tryParse(v)?.toLocal();
    }

    return InfoSincronizacion(
      configurado: supabaseConfigurado,
      emailSesion: email,
      ultimoSync: fecha(_kUltimoSync),
      ultimoError: prefs?.getString(_kUltimoError),
      ultimoErrorEn: fecha(_kUltimoErrorEn),
    );
  }

  Future<void> _registrarExito(DateTime en) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_kUltimoSync, en.toUtc().toIso8601String());
    await prefs.remove(_kUltimoError);
    await prefs.remove(_kUltimoErrorEn);
  }

  Future<void> _registrarError(String mensaje) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_kUltimoError, mensaje);
    await prefs.setString(
        _kUltimoErrorEn, DateTime.now().toUtc().toIso8601String());
  }

  // ------------------------------------------------ sync con Supabase

  /// Comprueba requisitos; devuelve el estado que impide sincronizar o
  /// `null` si se puede.
  Future<SyncState?> _impedimento() async {
    if (!supabaseConfigurado) return SyncNoConfigurado();
    if (_cliente?.auth.currentUser == null) return SyncSinSesion();
    if (!await networkInfo.isConnected) return SyncOffline();
    return null;
  }

  /// Sincroniza notas y cursos del usuario de la sesión con Supabase:
  ///   1. sube lo local que falte en remoto o sea más reciente que remoto;
  ///   2. descarga lo remoto (que ya incluye lo recién subido).
  /// Así no se pisa una edición local con una copia remota más antigua.
  /// Lanza si Supabase no responde.
  Future<DateTime> _sincronizarSupabase() async {
    final cliente = _cliente!;
    final userId = cliente.auth.currentUser!.id;
    final inicio = DateTime.now();

    final helper = sl.isRegistered<SupabaseSyncHelper>()
        ? sl<SupabaseSyncHelper>()
        : null;
    if (helper == null) {
      throw StateError('Servicio de sincronización no disponible');
    }

    /// id -> updated_at remoto. Además sirve de sonda: los métodos del
    /// helper silencian errores y esta consulta los hace visibles.
    Future<Map<String, DateTime>> remotas(String tabla) async {
      final filas = await cliente
          .from(tabla)
          .select('id, updated_at')
          .eq('user_id', userId);
      return {
        for (final f in (filas as List).cast<Map<String, dynamic>>())
          f['id'] as String:
              DateTime.tryParse(f['updated_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
      };
    }

    bool masNueva(String id, DateTime local, Map<String, DateTime> remoto) {
      final r = remoto[id];
      return r == null || local.toUtc().isAfter(r.toUtc());
    }

    if (sl.isRegistered<CoursesLocalDataSource>()) {
      final remoto = await remotas('courses');
      for (final c in await sl<CoursesLocalDataSource>().getAllCourses(userId)) {
        if (masNueva(c.id, c.updatedAt, remoto)) await helper.pushCourse(c);
      }
    }
    if (sl.isRegistered<NotesLocalDataSource>()) {
      final remoto = await remotas('app_notes');
      for (final n in await sl<NotesLocalDataSource>().getAllNotes(userId)) {
        if (masNueva(n.id, n.updatedAt, remoto)) await helper.pushNote(n);
      }
    }

    await helper.pullAll();
    return inicio;
  }

  String _mensajeError(Object e) {
    if (e is PostgrestException) return 'Supabase: ${e.message}';
    if (e is AuthException) return 'Sesión: ${e.message}';
    final texto = e.toString();
    if (texto.contains('SocketException') || texto.contains('Failed host')) {
      return 'Sin conexión con Supabase';
    }
    return texto.length > 200 ? '${texto.substring(0, 200)}…' : texto;
  }

  Future<void> _onSyncStarted(
    SyncStarted event,
    Emitter<SyncState> emit,
  ) async {
    final bloqueo = await _impedimento();
    if (bloqueo != null) {
      emit(bloqueo);
      return;
    }

    emit(SyncInProgress());
    try {
      final en = await _sincronizarSupabase();
      await _registrarExito(en);
      emit(SyncSuccess(syncedAt: en));
    } catch (e, st) {
      AppLogger.e('Sync: fallo sincronizando con Supabase', e, st);
      final mensaje = _mensajeError(e);
      await _registrarError(mensaje);
      emit(SyncFailure(mensaje));
    }
  }

  Future<void> _onSyncAutoStarted(
    SyncAutoStarted event,
    Emitter<SyncState> emit,
  ) async {
    // Silenciosa: sin estado "en curso" para no parpadear en la UI.
    final bloqueo = await _impedimento();
    if (bloqueo != null) {
      emit(bloqueo);
      return;
    }
    try {
      final en = await _sincronizarSupabase();
      await _registrarExito(en);
      emit(SyncSuccess(syncedAt: en));
    } catch (e, st) {
      // Se registra para el perfil, pero no se molesta al usuario.
      AppLogger.w('Sync automático falló: $e\n$st');
      await _registrarError(_mensajeError(e));
    }
  }

  // ------------------------------------- sincronización heredada (Drift)

  Future<void> _onSyncPullRequested(
    SyncPullRequested event,
    Emitter<SyncState> emit,
  ) async {
    final isOnline = await networkInfo.isConnected;
    if (!isOnline) {
      emit(SyncOffline());
      return;
    }

    emit(SyncInProgress());

    try {
      await syncService.pullChanges();
      emit(SyncSuccess(syncedAt: DateTime.now()));
    } catch (e) {
      emit(SyncFailure('Error al descargar cambios: $e'));
    }
  }

  Future<void> _onSyncPushRequested(
    SyncPushRequested event,
    Emitter<SyncState> emit,
  ) async {
    final isOnline = await networkInfo.isConnected;
    if (!isOnline) {
      emit(SyncOffline());
      return;
    }

    emit(SyncInProgress());

    try {
      await syncService.pushChanges();
      emit(SyncSuccess(syncedAt: DateTime.now()));
    } catch (e) {
      emit(SyncFailure('Error al subir cambios: $e'));
    }
  }
}
