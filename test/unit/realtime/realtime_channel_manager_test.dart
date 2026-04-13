import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/realtime/channel_handle.dart';
import 'package:app/app/realtime/channel_names.dart';
import 'package:app/app/realtime/realtime_channel_manager.dart';

void main() {
  late FakeBroadcastManager fake;
  late RealtimeChannelManager manager;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    fake = Echo.fake();
    manager = RealtimeChannelManager(broadcaster: fake);
  });

  tearDown(() {
    manager.dispose();
    Echo.unfake();
  });

  // -------------------------------------------------------------------------
  // Eager subscription
  // -------------------------------------------------------------------------

  group('RealtimeChannelManager subscription', () {
    test('channel() subscribes synchronously without HTTP', () {
      final name = ChannelName.conversation('abc');

      final handle = manager.channel(name);

      expect(handle, isA<ChannelHandle>());
      expect(handle.name, equals(name));
      // FakeBroadcastDriver.private records 'private-{key}'.
      fake.assertSubscribed('private-${name.key}');
    });

    test(
      'two calls for the same channel share one underlying subscription',
      () {
        final name = ChannelName.project('p1');

        final handleA = manager.channel(name);
        final handleB = manager.channel(name);

        expect(identical(handleA, handleB), isFalse);
        // Subscribed exactly once at the driver level.
        expect(
          fake.driver.subscribedChannels
              .where((c) => c == 'private-${name.key}')
              .length,
          equals(1),
        );
      },
    );

    test('different channel names produce independent subscriptions', () {
      final convo = ChannelName.conversation('c1');
      final session = ChannelName.session('s1');

      manager.channel(convo);
      manager.channel(session);

      fake.assertSubscribed('private-${convo.key}');
      fake.assertSubscribed('private-${session.key}');
    });
  });

  // -------------------------------------------------------------------------
  // Refcount + dispose
  // -------------------------------------------------------------------------

  group('RealtimeChannelManager refcount', () {
    test('disposing the only handle leaves the underlying channel', () {
      final name = ChannelName.task('t1');

      final handle = manager.channel(name);
      handle.dispose();

      fake.assertNotSubscribed('private-${name.key}');
    });

    test('underlying channel stays subscribed while any handle is alive', () {
      final name = ChannelName.team('tm1');

      final handleA = manager.channel(name);
      final handleB = manager.channel(name);

      handleA.dispose();

      // Still one consumer left.
      fake.assertSubscribed('private-${name.key}');

      handleB.dispose();

      fake.assertNotSubscribed('private-${name.key}');
    });

    test('double-dispose of the same handle does not double-decrement', () {
      final name = ChannelName.conversation('dd');

      final handleA = manager.channel(name);
      manager.channel(name); // handleB stays alive

      handleA.dispose();
      handleA.dispose(); // idempotent

      // Second handle still alive, channel must stay subscribed.
      fake.assertSubscribed('private-${name.key}');
    });

    test('disposeHandle() delegates to handle dispose', () {
      final name = ChannelName.session('ds');
      final handle = manager.channel(name);

      manager.disposeHandle(handle);

      fake.assertNotSubscribed('private-${name.key}');
      expect(handle.isDisposed, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Reconnect proxy
  // -------------------------------------------------------------------------

  group('RealtimeChannelManager onReconnect', () {
    test('exposes a broadcast stream for reconnect events', () {
      // Fake driver's onReconnect is empty; we just verify the stream exists
      // and is broadcast (multiple subscribers allowed).
      final stream = manager.onReconnect;

      expect(stream, isA<Stream<void>>());
      // ignore: unawaited_futures
      stream.listen((_) {});
      // ignore: unawaited_futures
      stream.listen((_) {});
      // No throw means broadcast.
    });
  });
}
