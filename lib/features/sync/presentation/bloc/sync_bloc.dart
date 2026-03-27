import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/network/network_info.dart';
import '../../../../core/services/sync_service.dart';

part 'sync_event.dart';
part 'sync_state.dart';

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncService syncService;
  final NetworkInfo networkInfo;

  SyncBloc({
    required this.syncService,
    required this.networkInfo,
  }) : super(SyncInitial()) {
    on<SyncStarted>(_onSyncStarted);
    on<SyncPullRequested>(_onSyncPullRequested);
    on<SyncPushRequested>(_onSyncPushRequested);
    on<SyncAutoStarted>(_onSyncAutoStarted);
  }

  Future<void> _onSyncStarted(
    SyncStarted event,
    Emitter<SyncState> emit,
  ) async {
    final isOnline = await networkInfo.isConnected;
    if (!isOnline) {
      emit(SyncOffline());
      return;
    }

    emit(SyncInProgress());

    final success = await syncService.fullSync();

    if (success) {
      emit(SyncSuccess(syncedAt: DateTime.now()));
    } else {
      emit(const SyncFailure('No se pudo completar la sincronización'));
    }
  }

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

  Future<void> _onSyncAutoStarted(
    SyncAutoStarted event,
    Emitter<SyncState> emit,
  ) async {
    // Auto-sync silently - don't emit InProgress to avoid UI flicker
    final isOnline = await networkInfo.isConnected;
    if (!isOnline) return;

    final success = await syncService.fullSync();

    if (success) {
      emit(SyncSuccess(syncedAt: DateTime.now()));
    }
    // On failure during auto-sync, stay in current state silently
  }
}
