part of 'sync_bloc.dart';

abstract class SyncState extends Equatable {
  const SyncState();

  @override
  List<Object?> get props => [];
}

class SyncInitial extends SyncState {}

class SyncInProgress extends SyncState {}

class SyncSuccess extends SyncState {
  final DateTime syncedAt;

  const SyncSuccess({required this.syncedAt});

  @override
  List<Object> get props => [syncedAt];
}

class SyncFailure extends SyncState {
  final String message;

  const SyncFailure(this.message);

  @override
  List<Object> get props => [message];
}

class SyncOffline extends SyncState {}
