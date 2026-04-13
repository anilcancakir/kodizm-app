import 'package:magic/magic.dart';

import 'package:app/app/realtime/buffered_event_queue.dart';
import 'package:app/app/realtime/channel_names.dart';

/// A ref-counted handle to a single broadcast channel subscription.
///
/// Returned eagerly by [RealtimeChannelManager.channel] and starts in
/// buffering mode. Events arriving before the consumer registers its handler
/// via [onEvent] are preserved in insertion order, then flushed once the
/// handler is set.
///
/// ## Usage
///
/// ```dart
/// final handle = manager.channel(ChannelName.conversation(id));
///
/// // Later, when the UI is ready to process events:
/// handle.onEvent((event) => handleEvent(event));
///
/// // Cleanup:
/// handle.dispose();
/// ```
class ChannelHandle {
  /// Creates a [ChannelHandle] for the given [name].
  ///
  /// The [onDispose] callback is invoked exactly once when this handle is
  /// disposed, allowing the manager to decrement its refcount.
  ChannelHandle({
    required this.name,
    required void Function(ChannelHandle handle) onDispose,
  }) : _onDispose = onDispose;

  // -------
  // State
  // -------

  /// The channel this handle is bound to.
  final ChannelName name;

  final void Function(ChannelHandle handle) _onDispose;
  final BufferedEventQueue<BroadcastEvent> _queue =
      BufferedEventQueue<BroadcastEvent>();
  bool _disposed = false;

  // -------
  // Accessors
  // -------

  /// Whether the consumer has registered its event handler via [onEvent].
  bool get isReady => _queue.isReady;

  /// Whether this handle has been disposed.
  bool get isDisposed => _disposed;

  // -------
  // Public API
  // -------

  /// Registers [handler] and flushes any buffered events in insertion order.
  ///
  /// Subsequent events are forwarded directly to [handler] without buffering.
  /// Calling this more than once is a no-op (the first handler wins).
  void onEvent(void Function(BroadcastEvent) handler) {
    if (_disposed) return;
    _queue.markReady(handler);
  }

  /// Dispatches an incoming [event] through the internal buffer.
  ///
  /// If the consumer has not yet called [onEvent], the event is buffered.
  /// Otherwise, it is forwarded immediately to the registered handler.
  void dispatch(BroadcastEvent event) {
    if (_disposed) return;
    _queue.dispatch(event);
  }

  /// Disposes this handle and notifies the manager to decrement refcount.
  ///
  /// Re-entrant safe: calling dispose more than once is a no-op.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _queue.clear();
    _onDispose(this);
  }
}
