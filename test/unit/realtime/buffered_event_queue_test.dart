import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/realtime/buffered_event_queue.dart';

void main() {
  group('BufferedEventQueue', () {
    late BufferedEventQueue<String> queue;

    setUp(() {
      queue = BufferedEventQueue<String>();
    });

    test('enqueue-then-flush preserves insertion order', () {
      queue.enqueue('a');
      queue.enqueue('b');
      queue.enqueue('c');

      expect(queue.bufferedCount, equals(3));

      final flushed = <String>[];
      queue.markReady(flushed.add);

      expect(flushed, equals(['a', 'b', 'c']));
      expect(queue.bufferedCount, equals(0));
    });

    test('dispatch-before-ready buffers events', () {
      queue.dispatch('x');
      queue.dispatch('y');

      expect(queue.isReady, isFalse);
      expect(queue.bufferedCount, equals(2));

      final flushed = <String>[];
      queue.markReady(flushed.add);

      expect(flushed, equals(['x', 'y']));
      expect(queue.bufferedCount, equals(0));
    });

    test('dispatch-after-ready bypasses buffer and calls handler directly', () {
      final received = <String>[];
      queue.markReady(received.add);

      expect(queue.isReady, isTrue);
      expect(queue.bufferedCount, equals(0));

      queue.dispatch('immediate');

      expect(received, equals(['immediate']));
      expect(queue.bufferedCount, equals(0));
    });

    test('double markReady is idempotent — second call is a no-op', () {
      final firstReceived = <String>[];
      final secondReceived = <String>[];

      queue.dispatch('before');

      queue.markReady(firstReceived.add);
      queue.markReady(secondReceived.add); // should be ignored

      // Only first handler should have received the buffered event.
      expect(firstReceived, equals(['before']));
      expect(secondReceived, isEmpty);

      // Subsequent dispatches go to the first handler, not the second.
      queue.dispatch('after');
      expect(firstReceived, equals(['before', 'after']));
      expect(secondReceived, isEmpty);
    });

    test('clear resets buffer, ready flag, and handler', () {
      queue.dispatch('buffered');
      expect(queue.bufferedCount, equals(1));

      final received = <String>[];
      queue.markReady(received.add);
      expect(queue.isReady, isTrue);

      queue.clear();

      expect(queue.isReady, isFalse);
      expect(queue.bufferedCount, equals(0));

      // After clear, dispatch should buffer again (no handler registered).
      queue.dispatch('post-clear');
      expect(queue.bufferedCount, equals(1));

      // Register a new handler — post-clear event flushed correctly.
      final newReceived = <String>[];
      queue.markReady(newReceived.add);
      expect(newReceived, equals(['post-clear']));
    });
  });
}
