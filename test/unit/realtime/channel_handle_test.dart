import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/realtime/channel_handle.dart';
import 'package:app/app/realtime/channel_names.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  // -------------------------------------------------------------------------
  // Buffering behaviour
  // -------------------------------------------------------------------------

  group('ChannelHandle buffering', () {
    test('starts in not-ready state and buffers dispatched events', () {
      final handle = ChannelHandle(
        name: ChannelName.conversation('abc'),
        onDispose: (_) {},
      );

      expect(handle.isReady, isFalse);

      handle.dispatch(_event('e1'));
      handle.dispatch(_event('e2'));

      // Events are buffered, not lost.
      final received = <BroadcastEvent>[];
      handle.onEvent(received.add);

      expect(handle.isReady, isTrue);
      expect(received.map((e) => e.event), equals(['e1', 'e2']));
    });

    test('flushes buffered events in insertion order on onEvent', () {
      final handle = ChannelHandle(
        name: ChannelName.session('s1'),
        onDispose: (_) {},
      );

      handle.dispatch(_event('first'));
      handle.dispatch(_event('second'));
      handle.dispatch(_event('third'));

      final order = <String>[];
      handle.onEvent((e) => order.add(e.event));

      expect(order, equals(['first', 'second', 'third']));
    });

    test('forwards events directly after onEvent is registered', () {
      final handle = ChannelHandle(
        name: ChannelName.project('p1'),
        onDispose: (_) {},
      );

      final received = <String>[];
      handle.onEvent((e) => received.add(e.event));

      handle.dispatch(_event('live1'));
      handle.dispatch(_event('live2'));

      expect(received, equals(['live1', 'live2']));
    });
  });

  // -------------------------------------------------------------------------
  // Dispose safety
  // -------------------------------------------------------------------------

  group('ChannelHandle dispose', () {
    test('invokes onDispose callback exactly once', () {
      var disposeCount = 0;
      final handle = ChannelHandle(
        name: ChannelName.task('t1'),
        onDispose: (_) => disposeCount++,
      );

      handle.dispose();

      expect(disposeCount, equals(1));
      expect(handle.isDisposed, isTrue);
    });

    test('double dispose is safe and does not double-invoke callback', () {
      var disposeCount = 0;
      final handle = ChannelHandle(
        name: ChannelName.team('tm1'),
        onDispose: (_) => disposeCount++,
      );

      handle.dispose();
      handle.dispose();

      expect(disposeCount, equals(1));
    });

    test('dispatch after dispose is silently ignored', () {
      final received = <String>[];
      final handle = ChannelHandle(
        name: ChannelName.conversation('c1'),
        onDispose: (_) {},
      );

      handle.onEvent((e) => received.add(e.event));
      handle.dispose();

      handle.dispatch(_event('after-dispose'));

      expect(received, isEmpty);
    });

    test('onEvent after dispose is silently ignored', () {
      final handle = ChannelHandle(
        name: ChannelName.conversation('c2'),
        onDispose: (_) {},
      );

      handle.dispatch(_event('buffered'));
      handle.dispose();

      final received = <String>[];
      handle.onEvent((e) => received.add(e.event));

      expect(received, isEmpty);
      expect(handle.isReady, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BroadcastEvent _event(String name) => BroadcastEvent(
  event: name,
  channel: 'test',
  data: const <String, dynamic>{},
  receivedAt: DateTime.now(),
);
