import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/events/websocket_event.dart';

void main() {
  group('WebSocketEvent', () {
    // ---------------------------------------------------------------------------
    // fromPusherPayload
    // ---------------------------------------------------------------------------

    test(
      'fromPusherPayload parses channel and eventName from Pusher envelope',
      () {
        final payload = {
          'event': 'App\\Events\\TaskUpdated',
          'channel': 'private-project.abc-123',
          'data': jsonEncode({
            'task_id': 'task-uuid-1',
            'status': 'in_progress',
          }),
        };

        final event = WebSocketEvent.fromPusherPayload(payload);

        expect(event.channel, equals('private-project.abc-123'));
        expect(event.eventName, equals('App\\Events\\TaskUpdated'));
      },
    );

    test('fromPusherPayload decodes JSON-encoded data string into Map', () {
      final innerData = {'task_id': 'task-uuid-1', 'status': 'done'};
      final payload = {
        'event': 'App\\Events\\TaskUpdated',
        'channel': 'private-project.abc-123',
        'data': jsonEncode(innerData),
      };

      final event = WebSocketEvent.fromPusherPayload(payload);

      expect(event.data, equals(innerData));
    });

    test(
      'fromPusherPayload generates composite id from channel+event+data',
      () {
        final payload = {
          'event': 'some.event',
          'channel': 'presence-channel',
          'data': jsonEncode({'key': 'value'}),
        };

        final event = WebSocketEvent.fromPusherPayload(payload);

        // ID format: '<channel>:<eventName>:<data.hashCode>'
        // The decoded Map instance is internal to the factory, so we verify
        // structure rather than the exact hash value.
        expect(event.id, startsWith('presence-channel:some.event:'));
        final parts = event.id.split(':');
        // 3 segments: channel, eventName, hashCode
        expect(parts.length, equals(3));
        expect(int.tryParse(parts.last), isNotNull);
      },
    );

    test('fromPusherPayload sets receivedAt to a recent DateTime', () {
      final before = DateTime.now();
      final payload = {
        'event': 'ping',
        'channel': 'general',
        'data': jsonEncode(<String, dynamic>{}),
      };

      final event = WebSocketEvent.fromPusherPayload(payload);
      final after = DateTime.now();

      expect(
        event.receivedAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        event.receivedAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('fromPusherPayload handles empty data object', () {
      final payload = {
        'event': 'pusher:connection_established',
        'channel': 'general',
        'data': jsonEncode(<String, dynamic>{}),
      };

      final event = WebSocketEvent.fromPusherPayload(payload);

      expect(event.data, isEmpty);
    });

    // ---------------------------------------------------------------------------
    // Field accessors
    // ---------------------------------------------------------------------------

    test('WebSocketEvent exposes all required fields', () {
      final now = DateTime.now();
      final data = <String, dynamic>{'foo': 'bar'};
      final event = WebSocketEvent(
        id: 'test-id',
        channel: 'test-channel',
        eventName: 'test.event',
        data: data,
        receivedAt: now,
      );

      expect(event.id, equals('test-id'));
      expect(event.channel, equals('test-channel'));
      expect(event.eventName, equals('test.event'));
      expect(event.data, equals(data));
      expect(event.receivedAt, equals(now));
    });
  });
}
