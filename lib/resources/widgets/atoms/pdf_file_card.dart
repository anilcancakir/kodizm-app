import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/message_attachment.dart';

/// Renders a PDF attachment as a tappable file card inside a chat bubble.
///
/// Displays a row with a PDF icon, the original filename, and the formatted
/// file size. Tapping opens the PDF URL in the system browser via
/// [Launch.url].
///
/// ## Usage
///
/// ```dart
/// PdfFileCard(attachment: pdfAttachment)
/// ```
class PdfFileCard extends StatelessWidget {
  /// Creates a [PdfFileCard] for the given PDF [attachment].
  const PdfFileCard({required this.attachment, super.key});

  // -------

  /// The PDF attachment to render. Must satisfy [attachment.isPdf].
  final MessageAttachment attachment;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WAnchor(
      onTap: () => Launch.url(attachment.url),
      child: WDiv(
        className:
            'flex flex-row items-center gap-2 p-2 rounded-lg bg-slate-100 dark:bg-slate-800',
        children: [
          WIcon(Icons.picture_as_pdf, className: 'text-red-500'),
          WDiv(
            className: 'flex flex-col flex-1',
            children: [
              WText(
                attachment.filename,
                className:
                    'text-xs font-medium text-primary-600 dark:text-slate-100',
              ),
              WText(
                attachment.sizeFormatted,
                className: 'text-[10px] text-slate-400',
              ),
            ],
          ),
          WIcon(Icons.open_in_new, className: 'text-xs text-slate-400'),
        ],
      ),
    );
  }
}
