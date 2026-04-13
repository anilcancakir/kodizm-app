import 'dart:async';

import 'package:magic/magic.dart';

import 'package:app/app/realtime/channel_handle.dart';
import 'package:app/app/realtime/channel_names.dart';

/// Internal bookkeeping for a single channel subscription shared across
/// multiple [ChannelHandle] instances.
class _ChannelEntry {
  _ChannelEntry({required this.subscription, required this.channelName});

  /// The underlying Echo stream subscription for this channel.
  final StreamSubscription<BroadcastEvent> subscription;

  /// The fully-qualified channel name returned by the driver (includes
  /// the `private-` prefix).
  final String channelName;

  /// All live handles sharing this subscription.
  final List<ChannelHandle> handles = [];
}

/// Centralized, ref-counted manager for broadcast channel subscriptions.
///
/// Wraps the Echo facade to provide single-flight subscriptions with automatic
/// fan-out to multiple consumers via [ChannelHandle]. Each handle independently
/// buffers events until its consumer is ready, closing the
/// subscribe-before-load race.
///
/// ## Usage
///
/// ```dart
/// final manager = RealtimeChannelManager();
/// final handle = manager.channel(ChannelName.conversation(id));
///
/// // Later, when consumer is ready:
/// handle.onEvent((event) => processEvent(event));
///
/// // Cleanup (unsubscribes when last handle for this channel disposes):
/// handle.dispose();
/// ```
class RealtimeChannelManager {
  /// Creates a [RealtimeChannelManager].
  ///
  /// Accepts an optional [broadcaster] for testability; defaults to resolving
  /// the Echo facade's underlying [BroadcastManager].
  RealtimeChannelManager({BroadcastManager? broadcaster})
    : _broadcaster = broadcaster;

  // -------
  // State
  // -------

  final BroadcastManager? _broadcaster;
  final Map<String, _ChannelEntry> _entries = {};
  final StreamController<void> _reconnectController =
      StreamController<void>.broadcast();
  StreamSubscription<void>? _reconnectSubscription;

  // -------
  // Accessors
  // -------

  /// Resolves the broadcast manager, falling back to the Echo facade default.
  BroadcastManager get _manager => _broadcaster ?? Echo.manager;

  /// A stream that emits once each time the underlying driver reconnects.
  ///
  /// Consumers can use this to trigger data re-fetches after a connection drop.
  Stream<void> get onReconnect => _reconnectController.stream;

  // -------
  // Public API
  // -------

  /// Returns a [ChannelHandle] for the given [name].
  ///
  /// On the first call for a given channel name, subscribes to the underlying
  /// Echo private channel eagerly (no HTTP call required). Subsequent calls
  /// for the same name share the single underlying subscription and increment
  /// the refcount.
  ChannelHandle channel(ChannelName name) {
    _ensureReconnectListener();

    final handle = ChannelHandle(name: name, onDispose: _onHandleDisposed);

    final entry = _entries[name.key];

    if (entry != null) {
      entry.handles.add(handle);
      return handle;
    }

    // First subscription for this channel name.
    final echoChannel = _manager.connection().private(name.key);
    final subscription = echoChannel.events.listen((event) {
      _fanOut(name.key, event);
    });

    _entries[name.key] = _ChannelEntry(
      subscription: subscription,
      channelName: echoChannel.name,
    )..handles.add(handle);

    return handle;
  }

  /// Explicitly disposes a [handle], decrementing the refcount.
  ///
  /// When the refcount for a channel reaches zero, the underlying Echo
  /// subscription is cancelled and the channel is left.
  void disposeHandle(ChannelHandle handle) {
    handle.dispose();
  }

  /// Tears down all subscriptions and closes the reconnect stream.
  void dispose() {
    _reconnectSubscription?.cancel();
    _reconnectSubscription = null;

    for (final entry in _entries.values) {
      entry.subscription.cancel();
      _manager.connection().leave(entry.channelName);
    }
    _entries.clear();

    _reconnectController.close();
  }

  // -------
  // Internal
  // -------

  /// Callback invoked by [ChannelHandle.dispose] to decrement refcount.
  void _onHandleDisposed(ChannelHandle handle) {
    final entry = _entries[handle.name.key];
    if (entry == null) return;

    entry.handles.remove(handle);

    if (entry.handles.isEmpty) {
      entry.subscription.cancel();
      _manager.connection().leave(entry.channelName);
      _entries.remove(handle.name.key);
    }
  }

  /// Fans out an incoming [event] to every live handle for [key].
  void _fanOut(String key, BroadcastEvent event) {
    final entry = _entries[key];
    if (entry == null) return;

    // Iterate over a copy in case a handler triggers dispose.
    for (final handle in List<ChannelHandle>.of(entry.handles)) {
      handle.dispatch(event);
    }
  }

  /// Lazily subscribes to the Echo driver's reconnect stream.
  void _ensureReconnectListener() {
    if (_reconnectSubscription != null) return;

    _reconnectSubscription = _manager.connection().onReconnect.listen((_) {
      _reconnectController.add(null);
    });
  }
}
