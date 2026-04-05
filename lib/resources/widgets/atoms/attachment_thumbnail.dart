import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/message_attachment.dart';

/// Renders an image attachment as a tappable thumbnail inside a chat bubble.
///
/// Displays the image constrained to 192×192px (w-48 h-48) with rounded
/// corners. Tapping opens a fullscreen [InteractiveViewer] dialog so the
/// user can pan and zoom the image.
///
/// A [CircularProgressIndicator] shimmer is shown while the network image
/// loads, and a broken-image placeholder is shown on error.
///
/// ## Usage
///
/// ```dart
/// AttachmentThumbnail(attachment: imageAttachment)
/// ```
class AttachmentThumbnail extends StatelessWidget {
  /// Creates an [AttachmentThumbnail] for the given image [attachment].
  const AttachmentThumbnail({required this.attachment, super.key});

  // -------

  /// The image attachment to render. Must satisfy [attachment.isImage].
  final MessageAttachment attachment;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WAnchor(
      onTap: () => _openFullscreen(context),
      child: WDiv(
        className: 'w-48 h-48 rounded-lg overflow-hidden',
        child: Image.network(
          attachment.url,
          fit: BoxFit.cover,
          semanticLabel: trans('chat.attachment_image'),
          loadingBuilder: _buildLoadingPlaceholder,
          errorBuilder: _buildErrorPlaceholder,
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Builders
  // -----------------------------------------------------------------------

  /// Shimmer placeholder rendered while the network image is loading.
  Widget _buildLoadingPlaceholder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) {
    if (loadingProgress == null) {
      return child;
    }

    return WDiv(
      className:
          'w-48 h-48 bg-slate-100 dark:bg-slate-800 rounded-lg flex items-center justify-center',
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
              : null,
        ),
      ),
    );
  }

  /// Placeholder shown when the image fails to load.
  Widget _buildErrorPlaceholder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return WDiv(
      className:
          'w-48 h-48 bg-slate-100 dark:bg-slate-800 rounded-lg flex items-center justify-center',
      child: WIcon(Icons.broken_image_outlined, className: 'text-slate-400'),
    );
  }

  // -----------------------------------------------------------------------
  // Fullscreen viewer
  // -----------------------------------------------------------------------

  /// Opens the image in a fullscreen [InteractiveViewer] dialog.
  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                attachment.url,
                fit: BoxFit.contain,
                semanticLabel: trans('chat.attachment_image'),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: WAnchor(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: WDiv(
                  className: 'p-2 rounded-full bg-black/50',
                  child: WIcon(Icons.close, className: 'text-white'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
