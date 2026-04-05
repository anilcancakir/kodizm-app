/// A file attached to a [ConversationMessage].
///
/// Lightweight plain-Dart data class — not a Magic ORM model.
/// Maps directly to `MessageAttachmentResource` from the Kodizm API.
///
/// ## Usage
/// ```dart
/// final attachment = MessageAttachment.fromMap(json['attachment']);
/// if (attachment.isImage) {
///   showImage(attachment.url);
/// }
/// print(attachment.sizeFormatted); // "1.2 MB"
/// ```
class MessageAttachment {
  // -------

  /// Creates a [MessageAttachment] with all fields.
  const MessageAttachment({
    required this.id,
    this.messageId,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.url,
    this.metadata,
    this.thumbnailUrl,
  });

  // -------

  /// The unique identifier of this attachment (UUID).
  final String id;

  /// The identifier of the parent message (UUID). Null for pre-upload attachments.
  final String? messageId;

  /// The original filename as uploaded by the user.
  final String filename;

  /// The MIME type of the attachment (e.g. `'image/png'`, `'application/pdf'`).
  final String mimeType;

  /// File size in bytes.
  final int size;

  /// Absolute URL to the stored file.
  final String url;

  /// Arbitrary metadata payload for this attachment. Null for most attachments.
  final Map<String, dynamic>? metadata;

  /// Thumbnail image URL for preview. Available for images and PDFs.
  final String? thumbnailUrl;

  // -------

  /// Returns `true` when the attachment is any image type (MIME starts with `image/`).
  bool get isImage => mimeType.startsWith('image/');

  /// Returns `true` when the attachment is a PDF document.
  bool get isPdf => mimeType == 'application/pdf';

  /// Returns a human-readable file size string.
  ///
  /// Formats as bytes (`512 B`), kilobytes (`200.0 KB`), or megabytes (`1.2 MB`)
  /// depending on magnitude.
  String get sizeFormatted {
    const kbThreshold = 1024;
    const mbThreshold = 1024 * 1024;

    if (size < kbThreshold) {
      return '$size B';
    }

    if (size < mbThreshold) {
      final kb = size / kbThreshold;
      return '${kb.toStringAsFixed(1)} KB';
    }

    final mb = size / mbThreshold;
    return '${mb.toStringAsFixed(1)} MB';
  }

  // -------

  /// Parses a [MessageAttachment] from a JSON-decoded map.
  static MessageAttachment fromMap(Map<String, dynamic> map) {
    return MessageAttachment(
      id: map['id'] as String,
      messageId: map['message_id'] as String?,
      filename: map['filename'] as String,
      mimeType: map['mime_type'] as String,
      size: map['size'] as int,
      url: map['url'] as String,
      metadata: map['metadata'] as Map<String, dynamic>?,
      thumbnailUrl: map['thumbnail_url'] as String?,
    );
  }
}
