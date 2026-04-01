import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

/// Sticky bottom input bar for the conversation chat screen.
///
/// Renders a native [TextField] with auto-expand (1–6 lines), keyboard shortcut
/// support (Enter=send, Shift+Enter=newline), a placeholder attachment button,
/// and an amber send button that disables when the input is empty or sending.
///
/// ## Usage
///
/// ```dart
/// ChatInputBar(
///   controller: _controller,
///   focusNode: _effectiveFocusNode,
///   isSending: state.isSending,
///   onSend: _handleSend,
/// )
/// ```
class ChatInputBar extends StatefulWidget {
  /// Creates a [ChatInputBar].
  const ChatInputBar({
    required this.controller,
    required this.isSending,
    this.awaitingResponse = false,
    this.focusNode,
    this.onSend,
    this.onStop,
    super.key,
  });

  /// Text controller owned by the parent view.
  final TextEditingController controller;

  /// Whether a send is in progress — disables the send button when true.
  final bool isSending;

  /// Whether the agent is currently processing — shows stop button when true.
  final bool awaitingResponse;

  /// Optional focus node passed from the parent. Falls back to an internal one.
  final FocusNode? focusNode;

  /// Callback fired when the send button is tapped or Enter is pressed.
  final VoidCallback? onSend;

  /// Callback fired when the stop button is tapped during agent processing.
  final VoidCallback? onStop;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final FocusNode _internalFocusNode;
  bool _isEmpty = true;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _effectiveFocusNode.onKeyEvent = _onKeyEvent;
    _isEmpty = widget.controller.text.isEmpty;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.onKeyEvent = null;
      _effectiveFocusNode.onKeyEvent = _onKeyEvent;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _effectiveFocusNode.onKeyEvent = null;
    _internalFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  void _onControllerChanged() {
    final empty = widget.controller.text.isEmpty;
    if (empty != _isEmpty) {
      setState(() => _isEmpty = empty);
    }
  }

  bool get _canSend => !_isEmpty && !widget.isSending;

  /// Handles keyboard events on the [TextField].
  ///
  /// - `Enter` (no modifiers) → fires [onSend] and swallows the event.
  /// - `Shift+Enter` → falls through to default newline insertion.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;

    if (!isEnter) return KeyEventResult.ignored;

    final shiftHeld = HardwareKeyboard.instance.isShiftPressed;

    if (shiftHeld) return KeyEventResult.ignored;

    if (_canSend) {
      widget.onSend?.call();
    }

    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WDiv(
      className:
          'w-full bg-white dark:bg-slate-900 px-3 py-3.5 border-t border-slate-200 dark:border-slate-700',
      children: [
        WDiv(
          className: 'flex flex-row gap-3 items-center axis-max',
          children: [
            // Attachment button (placeholder — functionality added later)
            WAnchor(
              onTap: null,
              child: WIcon(
                Icons.attach_file_rounded,
                className: 'text-xl text-slate-400 dark:text-slate-600',
              ),
            ),

            // Input — rounded bg container with TextField inside
            WDiv(
              className:
                  'flex-1 px-4 py-2.5 rounded-xl bg-slate-100 dark:bg-slate-800',
              child: TextField(
                controller: widget.controller,
                focusNode: _effectiveFocusNode,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 6,
                style: TextStyle(
                  fontFamily: 'AlbertSans',
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFFF1F5F9) // slate-100
                      : const Color(0xFF1E293B), // slate-900
                ),
                decoration: InputDecoration.collapsed(
                  hintText: trans('conversation_chat.placeholder'),
                  hintStyle: const TextStyle(
                    fontFamily: 'AlbertSans',
                    fontSize: 14,
                    color: Color(0xFF94A3B8), // slate-400
                  ),
                ),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ),

            // Send / Stop button
            if (widget.awaitingResponse)
              WAnchor(
                onTap: widget.onStop,
                child: WDiv(
                  className:
                      'w-10 h-10 rounded-full bg-red-500 flex items-center justify-center',
                  child: WIcon(
                    Icons.stop_rounded,
                    className: 'text-base text-white',
                  ),
                ),
              )
            else
              WAnchor(
                onTap: _canSend ? widget.onSend : null,
                child: WDiv(
                  className: _canSend
                      ? 'w-10 h-10 rounded-full bg-amber-400 flex items-center justify-center'
                      : 'w-10 h-10 rounded-full bg-slate-300 dark:bg-slate-600 flex items-center justify-center',
                  child: WIcon(
                    Icons.send,
                    className: 'text-base text-slate-900',
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
