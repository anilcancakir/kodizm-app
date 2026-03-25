import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Renders Markdown content with DESIGN.md-aligned typography and
/// syntax-highlighted fenced code blocks.
///
/// Wraps [MarkdownBody] with GitHub-flavored Markdown extension set,
/// Kodizm DESIGN.md tokens applied via [MarkdownStyleSheet], and a
/// custom [_CodeBlockBuilder] for `pre`/code blocks.
///
/// ## Usage
///
/// ```dart
/// MarkdownViewer(
///   data: '# Hello\n\nSome `inline code` and a paragraph.',
/// )
///
/// // With selection disabled (e.g. inside a non-interactive card):
/// MarkdownViewer(
///   data: markdownString,
///   selectable: false,
/// )
/// ```
///
/// **Justified exception**: [MarkdownStyleSheet] requires raw [TextStyle] /
/// [BoxDecoration] values — this is the same justified exception as
/// [SelectableText]. Wind UI className cannot be used here.
class MarkdownViewer extends StatelessWidget {
  /// Creates a [MarkdownViewer].
  ///
  /// [data] is the Markdown string to render.
  /// [selectable] enables text selection (default `true`).
  const MarkdownViewer({super.key, required this.data, this.selectable = true});

  /// The Markdown content to render.
  final String data;

  /// Whether the rendered text is selectable by the user.
  final bool selectable;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final MarkdownBody body = MarkdownBody(
      data: data,
      selectable: false, // Selection handled below via SelectableRegion.
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: _buildStyleSheet(context),
      builders: <String, MarkdownElementBuilder>{'pre': _CodeBlockBuilder()},
      onTapLink: _handleLinkTap,
    );

    if (!selectable) {
      return body;
    }

    return SelectionArea(child: body);
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Builds a [MarkdownStyleSheet] seeded from the current [Theme] and
  /// overridden with DESIGN.md tokens.
  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      // Inline code — JetBrains Mono, teal accent, subtle navy tint bg.
      code: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 13,
        color: Color(0xFF14B8A6),
        backgroundColor: Color(0x0F334E68),
      ),
      // Table heading — semi-bold weight.
      tableHead: const TextStyle(fontWeight: FontWeight.w600),
      // Table border — slate-200.
      tableBorder: TableBorder.all(color: const Color(0xFFE2E8F0)),
      // Blockquote — light slate bg + primary navy left border.
      blockquoteDecoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(left: BorderSide(color: Color(0xFF334E68), width: 3)),
      ),
      // Links — primary navy + underline.
      a: const TextStyle(
        color: Color(0xFF334E68),
        decoration: TextDecoration.underline,
      ),
    );
  }

  /// Handles taps on Markdown links.
  ///
  /// External http/https URLs are opened via [launchUrl]. Internal
  /// anchor links are ignored — callers can extend this behaviour by
  /// wrapping [MarkdownViewer] and intercepting routes.
  void _handleLinkTap(String text, String? href, String title) {
    if (href == null) return;
    if (href.startsWith('http://') || href.startsWith('https://')) {
      launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
    }
  }
}

// ---------------------------------------------------------------------------
// Private: code block builder
// ---------------------------------------------------------------------------

/// Custom [MarkdownElementBuilder] for `pre` elements.
///
/// Renders fenced code blocks with [HighlightView] (atom-one-dark theme)
/// and a clipboard copy button.
///
/// **Justified exception**: Raw Flutter widgets ([DecoratedBox], [Stack],
/// [Positioned], [IconButton]) are used here because this builder runs
/// outside the normal Wind UI layout tree — the markdown builder API
/// does not support Wind UI's className system.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  // -----------------------------------------------------------------------
  // MarkdownElementBuilder overrides
  // -----------------------------------------------------------------------

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final String code = _extractCode(element);
    final String language = _extractLanguage(element);

    return _CodeBlock(code: code, language: language);
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Extracts the raw text content of the `pre` element.
  String _extractCode(md.Element element) {
    return element.textContent;
  }

  /// Extracts the language hint from the first nested `code` element's
  /// CSS class (e.g. `language-dart` → `dart`).
  String _extractLanguage(md.Element element) {
    final List<md.Node>? children = element.children;
    if (children == null || children.isEmpty) return 'plaintext';

    // The first child of a fenced code block is a <code> element.
    final md.Node firstChild = children.first;
    if (firstChild is! md.Element) return 'plaintext';

    final String? cssClass = firstChild.attributes['class'];
    if (cssClass == null) return 'plaintext';

    // Format: "language-dart" → "dart"
    if (cssClass.startsWith('language-')) {
      return cssClass.substring('language-'.length);
    }
    return 'plaintext';
  }
}

// ---------------------------------------------------------------------------
// Private: stateless code block widget
// ---------------------------------------------------------------------------

/// Renders a styled code block with syntax highlighting and a copy button.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.language});

  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    // Code block container — HighlightView requires TextStyle + EdgeInsets
    // internally (third-party widget exception, similar to MarkdownStyleSheet).
    return WDiv(
      className: 'bg-primary-900 rounded-lg',
      child: Stack(
        children: <Widget>[
          // Syntax-highlighted source.
          WDiv(
            className: 'p-4',
            child: HighlightView(
              code,
              language: language,
              theme: atomOneDarkTheme,
              textStyle: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
          // Copy-to-clipboard button.
          Positioned(
            top: 8,
            right: 8,
            child: WAnchor(
              onTap: () => Clipboard.setData(ClipboardData(text: code)),
              child: WDiv(
                className: 'p-1.5 rounded bg-primary-300/10',
                child: WIcon(Icons.copy, className: 'text-sm text-primary-300'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
