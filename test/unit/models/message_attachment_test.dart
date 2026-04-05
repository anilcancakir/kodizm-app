import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/models/message_attachment.dart';

void main() {
  /// Tests for [MessageAttachment] data class.
  group('MessageAttachment', () {
    final baseMap = <String, dynamic>{
      'id': 'att-001',
      'message_id': 'msg-123',
      'filename': 'screenshot.png',
      'mime_type': 'image/png',
      'size': 204800,
      'url': 'https://cdn.kodizm.test/attachments/screenshot.png',
    };

    // -------

    group('fromMap', () {
      test('parses all required fields', () {
        final attachment = MessageAttachment.fromMap(baseMap);

        expect(attachment.id, equals('att-001'));
        expect(attachment.messageId, equals('msg-123'));
        expect(attachment.filename, equals('screenshot.png'));
        expect(attachment.mimeType, equals('image/png'));
        expect(attachment.size, equals(204800));
        expect(
          attachment.url,
          equals('https://cdn.kodizm.test/attachments/screenshot.png'),
        );
        expect(attachment.metadata, isNull);
      });

      test('parses optional metadata when present', () {
        final map = {
          ...baseMap,
          'metadata': {'width': 1920, 'height': 1080},
        };

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.metadata, equals({'width': 1920, 'height': 1080}));
      });

      test('leaves metadata null when absent', () {
        final attachment = MessageAttachment.fromMap(baseMap);

        expect(attachment.metadata, isNull);
      });
    });

    // -------

    group('isImage', () {
      test('returns true for image/png', () {
        final attachment = MessageAttachment.fromMap(baseMap);

        expect(attachment.isImage, isTrue);
      });

      test('returns true for image/jpeg', () {
        final map = {...baseMap, 'mime_type': 'image/jpeg'};

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.isImage, isTrue);
      });

      test('returns true for image/gif', () {
        final map = {...baseMap, 'mime_type': 'image/gif'};

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.isImage, isTrue);
      });

      test('returns false for application/pdf', () {
        final map = {...baseMap, 'mime_type': 'application/pdf'};

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.isImage, isFalse);
      });

      test('returns false for text/plain', () {
        final map = {...baseMap, 'mime_type': 'text/plain'};

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.isImage, isFalse);
      });
    });

    // -------

    group('isPdf', () {
      test('returns true for application/pdf', () {
        final map = {...baseMap, 'mime_type': 'application/pdf'};

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.isPdf, isTrue);
      });

      test('returns false for image/png', () {
        final attachment = MessageAttachment.fromMap(baseMap);

        expect(attachment.isPdf, isFalse);
      });

      test('returns false for text/plain', () {
        final map = {...baseMap, 'mime_type': 'text/plain'};

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.isPdf, isFalse);
      });
    });

    // -------

    group('sizeFormatted', () {
      test('formats bytes under 1 KB as "X B"', () {
        final map = {...baseMap, 'size': 512};

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.sizeFormatted, equals('512 B'));
      });

      test('formats exactly 1024 bytes as "1.0 KB"', () {
        final map = {...baseMap, 'size': 1024};

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.sizeFormatted, equals('1.0 KB'));
      });

      test('formats kilobytes range correctly', () {
        final map = {...baseMap, 'size': 204800};

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.sizeFormatted, equals('200.0 KB'));
      });

      test('formats megabytes range correctly', () {
        final map = {...baseMap, 'size': 1258291};

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.sizeFormatted, equals('1.2 MB'));
      });

      test('formats exactly 1 MB', () {
        final map = {...baseMap, 'size': 1048576};

        final attachment = MessageAttachment.fromMap(map);

        expect(attachment.sizeFormatted, equals('1.0 MB'));
      });
    });
  });
}
