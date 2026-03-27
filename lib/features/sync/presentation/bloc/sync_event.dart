part of 'sync_bloc.dart';

abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered manually by the user to perform a full sync.
class SyncStarted extends SyncEvent {
  const SyncStarted();
}

/// Triggered to pull remote changes only.
class SyncPullRequested extends SyncEvent {
  const SyncPullRequested();
}

/// Triggered to push local changes only.
class SyncPushRequested extends SyncEvent {
  const SyncPushRequested();
}

/// Triggered automatically (e.g., on app resume, after auth).
/// Syncs silently without showing loading indicators.
class SyncAutoStarted extends SyncEvent {
  const SyncAutoStarted();
}
