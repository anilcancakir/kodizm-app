import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/models/conversation_message.dart';
import 'package:app/app/models/message_attachment.dart';

void main() {
  /// Tests for [ConversationMessage] model.
  group('ConversationMessage', () {
    final baseMap = <String, dynamic>{
      'id': 'msg-123',
      'conversation_id': 'conv-456',
      'role': 'assistant',
      'content': 'Hello, world!',
      'created_at': '2026-04-04T10:00:00Z',
    };

    test('fromMap parses status field when present', () {
      final map = {...baseMap, 'status': 'queued'};

      final message = ConversationMessage.fromMap(map);

      expect(message.status, equals('queued'));
    });

    test('fromMap parses status as null when absent', () {
      final message = ConversationMessage.fromMap(baseMap);

      expect(message.status, isNull);
    });

    test('fromMap handles various status values', () {
      const statuses = [
        'queued',
        'processing',
        'completed',
        'failed',
        'cancelled',
      ];

      for (final status in statuses) {
        final map = {...baseMap, 'status': status};

        final message = ConversationMessage.fromMap(map);

        expect(message.status, equals(status));
      }
    });

    test('copyWith preserves status when not specified', () {
      final map = {...baseMap, 'status': 'processing'};

      final original = ConversationMessage.fromMap(map);
      final copied = original.copyWith(content: 'Updated content');

      expect(copied.status, equals('processing'));
      expect(copied.content, equals('Updated content'));
    });

    test('copyWith updates status when specified', () {
      final map = {...baseMap, 'status': 'processing'};

      final original = ConversationMessage.fromMap(map);
      final copied = original.copyWith(status: 'completed');

      expect(copied.status, equals('completed'));
    });

    test('copyWith can set status to null', () {
      final map = {...baseMap, 'status': 'queued'};

      final original = ConversationMessage.fromMap(map);
      final copied = original.copyWith(status: null);

      expect(copied.status, isNull);
    });

    test('fromMap preserves all existing fields alongside status', () {
      final map = {
        ...baseMap,
        'status': 'completed',
        'metadata': {'key': 'value'},
        'cost_usd': '0.05',
        'usage': {'input_tokens': 100, 'output_tokens': 50},
        'duration_ms': 1250,
        'num_turns': 2,
        'error': null,
        'started_at': '2026-04-04T09:59:00Z',
        'completed_at': '2026-04-04T10:00:00Z',
      };

      final message = ConversationMessage.fromMap(map);

      expect(message.id, equals('msg-123'));
      expect(message.conversationId, equals('conv-456'));
      expect(message.role, equals('assistant'));
      expect(message.content, equals('Hello, world!'));
      expect(message.status, equals('completed'));
      expect(message.metadata, equals({'key': 'value'}));
      expect(message.costUsd, equals(0.05));
      expect(message.usage, equals({'input_tokens': 100, 'output_tokens': 50}));
      expect(message.durationMs, equals(1250));
      expect(message.numTurns, equals(2));
      expect(message.error, isNull);
      expect(message.startedAt, isNotNull);
      expect(message.completedAt, isNotNull);
      expect(message.createdAt, isNotNull);
    });

    // -------

    group('nullable content', () {
      test('fromMap accepts null content without crashing', () {
        final map = <String, dynamic>{
          'id': 'msg-123',
          'conversation_id': 'conv-456',
          'role': 'user',
          'content': null,
          'created_at': '2026-04-04T10:00:00Z',
        };

        final message = ConversationMessage.fromMap(map);

        expect(message.content, isNull);
      });

      test('fromMap parses non-null content normally', () {
        final message = ConversationMessage.fromMap(baseMap);

        expect(message.content, equals('Hello, world!'));
      });

      test('copyWith preserves null content', () {
        final map = <String, dynamic>{
          'id': 'msg-123',
          'conversation_id': 'conv-456',
          'role': 'user',
          'content': null,
          'created_at': '2026-04-04T10:00:00Z',
        };

        final original = ConversationMessage.fromMap(map);
        final copied = original.copyWith(status: 'queued');

        expect(copied.content, isNull);
      });

      test('copyWith can update content from null to a value', () {
        final map = <String, dynamic>{
          'id': 'msg-123',
          'conversation_id': 'conv-456',
          'role': 'user',
          'content': null,
          'created_at': '2026-04-04T10:00:00Z',
        };

        final original = ConversationMessage.fromMap(map);
        final copied = original.copyWith(content: 'Now has content');

        expect(copied.content, equals('Now has content'));
      });
    });

    // -------

    group('attachments', () {
      test('fromMap defaults attachments to empty list when absent', () {
        final message = ConversationMessage.fromMap(baseMap);

        expect(message.attachments, isEmpty);
        expect(message.hasAttachments, isFalse);
      });

      test('fromMap parses attachments list', () {
        final map = {
          ...baseMap,
          'attachments': [
            {
              'id': 'att-001',
              'message_id': 'msg-123',
              'filename': 'photo.jpg',
              'mime_type': 'image/jpeg',
              'size': 512000,
              'url': 'https://cdn.kodizm.test/photo.jpg',
            },
          ],
        };

        final message = ConversationMessage.fromMap(map);

        expect(message.attachments, hasLength(1));
        expect(message.attachments.first.filename, equals('photo.jpg'));
        expect(message.hasAttachments, isTrue);
      });

      test('fromMap parses multiple attachments', () {
        final map = {
          ...baseMap,
          'attachments': [
            {
              'id': 'att-001',
              'message_id': 'msg-123',
              'filename': 'photo.jpg',
              'mime_type': 'image/jpeg',
              'size': 512000,
              'url': 'https://cdn.kodizm.test/photo.jpg',
            },
            {
              'id': 'att-002',
              'message_id': 'msg-123',
              'filename': 'document.pdf',
              'mime_type': 'application/pdf',
              'size': 1048576,
              'url': 'https://cdn.kodizm.test/document.pdf',
            },
          ],
        };

        final message = ConversationMessage.fromMap(map);

        expect(message.attachments, hasLength(2));
        expect(message.attachments[0].isImage, isTrue);
        expect(message.attachments[1].isPdf, isTrue);
      });

      test('fromMap with null content and attachments does not crash', () {
        final map = <String, dynamic>{
          'id': 'msg-123',
          'conversation_id': 'conv-456',
          'role': 'user',
          'content': null,
          'created_at': '2026-04-04T10:00:00Z',
          'attachments': [
            {
              'id': 'att-001',
              'message_id': 'msg-123',
              'filename': 'screenshot.png',
              'mime_type': 'image/png',
              'size': 204800,
              'url': 'https://cdn.kodizm.test/screenshot.png',
            },
          ],
        };

        final message = ConversationMessage.fromMap(map);

        expect(message.content, isNull);
        expect(message.attachments, hasLength(1));
        expect(message.hasAttachments, isTrue);
      });

      test('copyWith preserves attachments when not specified', () {
        final map = {
          ...baseMap,
          'attachments': [
            {
              'id': 'att-001',
              'message_id': 'msg-123',
              'filename': 'photo.jpg',
              'mime_type': 'image/jpeg',
              'size': 512000,
              'url': 'https://cdn.kodizm.test/photo.jpg',
            },
          ],
        };

        final original = ConversationMessage.fromMap(map);
        final copied = original.copyWith(status: 'completed');

        expect(copied.attachments, hasLength(1));
        expect(copied.attachments.first.filename, equals('photo.jpg'));
      });

      test(
        'copyWith with attachments list replaces the existing attachments',
        () {
          final map = {
            ...baseMap,
            'attachments': [
              {
                'id': 'att-001',
                'message_id': 'msg-123',
                'filename': 'photo.jpg',
                'mime_type': 'image/jpeg',
                'size': 512000,
                'url': 'https://cdn.kodizm.test/photo.jpg',
              },
            ],
          };

          final original = ConversationMessage.fromMap(map);
          final replacement = MessageAttachment.fromMap({
            'id': 'att-002',
            'message_id': 'msg-123',
            'filename': 'new.png',
            'mime_type': 'image/png',
            'size': 1024,
            'url': 'https://cdn.kodizm.test/new.png',
          });
          final copied = original.copyWith(attachments: [replacement]);

          expect(copied.attachments, hasLength(1));
          expect(copied.attachments.first.filename, equals('new.png'));
        },
      );
    });
  });
}
