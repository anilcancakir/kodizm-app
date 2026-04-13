import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/realtime/channel_names.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  // -------------------------------------------------------------------------
  // ChannelName factories — key shape
  // -------------------------------------------------------------------------

  group('ChannelName.key', () {
    test('conversation returns conversation.{id}', () {
      expect(ChannelName.conversation('abc').key, equals('conversation.abc'));
    });

    test('session returns session.{id}', () {
      expect(ChannelName.session('abc').key, equals('session.abc'));
    });

    test('project returns project.{id}', () {
      expect(ChannelName.project('abc').key, equals('project.abc'));
    });

    test('task returns task.{id}', () {
      expect(ChannelName.task('abc').key, equals('task.abc'));
    });

    test('team returns team.{id}', () {
      expect(ChannelName.team('abc').key, equals('team.abc'));
    });

    test('key includes full UUID', () {
      const uuid = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
      expect(ChannelName.project(uuid).key, equals('project.$uuid'));
    });
  });

  // -------------------------------------------------------------------------
  // ChannelName.kind
  // -------------------------------------------------------------------------

  group('ChannelName.kind', () {
    test('conversation kind is ChannelKind.conversation', () {
      expect(
        ChannelName.conversation('abc').kind,
        equals(ChannelKind.conversation),
      );
    });

    test('session kind is ChannelKind.session', () {
      expect(ChannelName.session('abc').kind, equals(ChannelKind.session));
    });

    test('project kind is ChannelKind.project', () {
      expect(ChannelName.project('abc').kind, equals(ChannelKind.project));
    });

    test('task kind is ChannelKind.task', () {
      expect(ChannelName.task('abc').kind, equals(ChannelKind.task));
    });

    test('team kind is ChannelKind.team', () {
      expect(ChannelName.team('abc').kind, equals(ChannelKind.team));
    });
  });

  // -------------------------------------------------------------------------
  // Equality + hashCode
  // -------------------------------------------------------------------------

  group('ChannelName equality', () {
    test('two instances with same key are equal', () {
      expect(
        ChannelName.conversation('abc'),
        equals(ChannelName.conversation('abc')),
      );
    });

    test('two instances with same key share hashCode', () {
      expect(
        ChannelName.project('x').hashCode,
        equals(ChannelName.project('x').hashCode),
      );
    });

    test('instances with different ids are not equal', () {
      expect(
        ChannelName.conversation('abc'),
        isNot(equals(ChannelName.conversation('def'))),
      );
    });

    test(
      'instances with different kinds but same id segment are not equal',
      () {
        expect(
          ChannelName.project('abc'),
          isNot(equals(ChannelName.task('abc'))),
        );
      },
    );

    test('can be used as Map key', () {
      final map = <ChannelName, int>{
        ChannelName.session('s1'): 1,
        ChannelName.team('t1'): 2,
      };

      expect(map[ChannelName.session('s1')], equals(1));
      expect(map[ChannelName.team('t1')], equals(2));
    });
  });
}
