/// A generic queue that buffers events until a consumer is ready to process them.
///
/// Solves the subscribe-before-load race: events arriving before the consumer
/// registers its handler are preserved in insertion order, then flushed once
/// [markReady] is called.
///
/// ## Usage
/// ```dart
/// final queue = BufferedEventQueue<MyEvent>();
///
/// // Producer side, can be called any time, even before markReady.
/// queue.dispatch(event);
///
/// // Consumer side, called once the UI / state is initialised.
/// queue.markReady((event) => handleEvent(event));
/// ```
class BufferedEventQueue<E> {
  final List<E> _buffer = [];
  void Function(E)? _handler;
  bool _ready = false;

  // -------
  // Accessors
  // -------

  /// Returns the number of events currently held in the buffer.
  int get bufferedCount => _buffer.length;

  /// Returns `true` after [markReady] has been called at least once.
  bool get isReady => _ready;

  // -------
  // Public API
  // -------

  /// Adds [event] to the internal buffer unconditionally.
  ///
  /// Prefer [dispatch] for normal producer use; this method exists for cases
  /// where explicit buffering without the ready-check is needed (e.g., tests).
  void enqueue(E event) => _buffer.add(event);

  /// Marks the queue as ready and registers [flushHandler] for all future events.
  ///
  /// All buffered events are immediately drained through [flushHandler] in
  /// insertion order. Subsequent calls to [dispatch] invoke [flushHandler]
  /// directly without buffering.
  ///
  /// Calling this method more than once is a no-op. The handler and ready
  /// state are frozen after the first call.
  void markReady(void Function(E) flushHandler) {
    if (_ready) return;

    _ready = true;
    _handler = flushHandler;

    for (final event in _buffer) {
      flushHandler(event);
    }
    _buffer.clear();
  }

  /// Primary entry point for producers.
  ///
  /// If the queue is not yet ready, the event is buffered. Once ready, the
  /// registered handler is invoked immediately without buffering.
  void dispatch(E event) {
    if (_ready) {
      _handler!(event);
    } else {
      _buffer.add(event);
    }
  }

  /// Resets the queue to its initial state.
  ///
  /// Clears the buffer, removes the handler, and resets the ready flag.
  /// After calling this, [dispatch] will buffer events again until a new
  /// [markReady] call is made.
  void clear() {
    _buffer.clear();
    _handler = null;
    _ready = false;
  }
}
