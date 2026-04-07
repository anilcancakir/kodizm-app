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
  ///
  /// Dark/light mode aware — applies appropriate palette from DESIGN.md §9.
  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // -- Palette (DESIGN.md §2 + §9) --
    final Color textBody = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF334E68);
    final Color textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color border = isDark
        ? const Color(0xFF243346)
        : const Color(0xFFE2E8F0);
    final Color blockquoteBg = isDark
        ? const Color(0xFF243346)
        : const Color(0xFFF8FAFC);
    final Color inlineCodeBg = isDark
        ? const Color(0x1FFFFFFF)
        : const Color(0x0F334E68);
    final Color linkColor = isDark
        ? const Color(0xFF60A5FA)
        : const Color(0xFF334E68);
    final Color tableCellBg = isDark
        ? const Color(0x08FFFFFF)
        : const Color(0x00000000);
    final Color tableHeadBg = isDark
        ? const Color(0x12FFFFFF)
        : const Color(0x08334E68);

    // -- Font families (DESIGN.md §3) --
    const String bodyFont = 'AlbertSans';
    const String monoFont = 'JetBrains Mono';

    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      // Body text — Albert Sans, primary readable color.
      p: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        height: 1.6,
        color: textBody,
      ),
      // Headings — DESIGN.md §3 constrained type scale.
      h1: TextStyle(
        fontFamily: bodyFont,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.01,
        color: textBody,
      ),
      h2: TextStyle(
        fontFamily: bodyFont,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.01,
        color: textBody,
      ),
      h3: TextStyle(
        fontFamily: bodyFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: textBody,
      ),
      // Inline code — JetBrains Mono, teal accent, subtle bg.
      code: TextStyle(
        fontFamily: monoFont,
        fontSize: 13,
        color: const Color(0xFF14B8A6),
        backgroundColor: inlineCodeBg,
      ),
      // Table heading — Albert Sans, semi-bold, subtle background.
      tableHead: TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w600,
        color: textBody,
      ),
      tableHeadAlign: TextAlign.left,
      // Table border — theme-aware, subtle.
      tableBorder: TableBorder.all(color: border, width: 0.5),
      // Table cell decoration — alternating-ready subtle tint.
      tableCellsDecoration: BoxDecoration(color: tableCellBg),
      // Table head cell decoration — slightly more prominent.
      tableHeadCellsDecoration: BoxDecoration(color: tableHeadBg),
      // Table cell padding — comfortable spacing.
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      // Table body text — Albert Sans.
      tableBody: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        height: 1.5,
        color: textBody,
      ),
      // Blockquote — theme-aware bg + accent left border.
      blockquoteDecoration: BoxDecoration(
        color: blockquoteBg,
        border: const Border(
          left: BorderSide(color: Color(0xFFFBBF24), width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      // Links — blue in dark mode for visibility, navy in light.
      a: TextStyle(
        fontFamily: bodyFont,
        color: linkColor,
        decoration: TextDecoration.underline,
        decorationColor: linkColor.withValues(alpha: 0.4),
      ),
      // List item bullets — secondary text color.
      listBullet: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        color: textSecondary,
      ),
      // Horizontal rule.
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: border, width: 1)),
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
///
/// Uses DESIGN.md Terminal card variant (`primary-900` bg) in both modes —
/// code blocks are always dark-on-dark for consistency and readability.
/// Horizontal scroll for long lines, language label top-left, copy top-right.
/// [atomOneDarkTheme] with transparent root background so the outer
/// `bg-primary-900` container shows through without a visible inner box.
final Map<String, TextStyle> _codeTheme = {
  ...atomOneDarkTheme,
  'root': TextStyle(
    color: atomOneDarkTheme['root']?.color,
    backgroundColor: const Color(0x00000000),
  ),
};

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.language});

  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    final hasLang = language != 'plaintext';

    return WDiv(
      className: 'bg-primary-900 rounded-lg overflow-hidden',
      child: WDiv(
        className: 'flex flex-col',
        children: [
          // Header row: language label + copy button.
          if (hasLang)
            WDiv(
              className:
                  'flex flex-row items-center justify-between px-3 pt-2.5',
              children: [
                WText(
                  language,
                  className: 'text-xs font-medium text-slate-500',
                ),
                _buildCopyButton(),
              ],
            ),
          // Copy button only (no language label).
          if (!hasLang)
            WDiv(
              className: 'flex flex-row justify-end px-3 pt-2.5',
              child: _buildCopyButton(),
            ),
          // Syntax-highlighted source with horizontal scroll.
          WDiv(
            className: 'px-3 pb-3 pt-1',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                code,
                language: language,
                theme: _codeTheme,
                textStyle: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  height: 1.6,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Copy-to-clipboard button — Wind UI only.
  Widget _buildCopyButton() {
    return WAnchor(
      onTap: () => Clipboard.setData(ClipboardData(text: code)),
      child: WDiv(
        className: 'p-1.5 rounded bg-white/5',
        child: WIcon(Icons.copy, className: 'text-sm text-slate-500'),
      ),
    );
  }
}
