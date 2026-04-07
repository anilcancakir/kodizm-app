import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

/// Sticky bottom input bar for the conversation chat screen.
///
/// Renders a native [TextField] with auto-expand (1–6 lines), keyboard shortcut
/// support (Enter=send, Shift+Enter=newline), an attachment picker button,
/// and an amber send button that disables when the input is empty or sending.
///
/// When [awaitingResponse] is true, both the send and stop buttons are visible
/// simultaneously so messages can be queued while the agent is executing.
/// A [queuedCount] badge appears above the input when messages are pending.
///
/// Selected attachments are shown as a preview strip above the text field.
/// Images display a thumbnail; PDFs display a file icon and name.
/// Each preview has an (×) remove button. Attachments are cleared after send.
///
/// Validation rules (enforced via [validateAndAddAttachments]):
/// - Maximum **4** files per message.
/// - Maximum **5 MB** per file.
///
/// ## Usage
///
/// ```dart
/// ChatInputBar(
///   controller: _controller,
///   focusNode: _effectiveFocusNode,
///   isSending: state.isSending,
///   queuedCount: state.queuedCount,
///   onSend: _handleSend,
///   onStop: _handleStop,
///   onAttachmentsChanged: (files) => state.setPendingAttachments(files),
/// )
/// ```
class ChatInputBar extends StatefulWidget {
  /// Creates a [ChatInputBar].
  const ChatInputBar({
    required this.controller,
    required this.isSending,
    this.awaitingResponse = false,
    this.disabled = false,
    this.isUploading = false,
    this.queuedCount = 0,
    this.focusNode,
    this.onSend,
    this.onStop,
    this.onCancelQueue,
    this.onAttachmentsChanged,
    this.onFilesAdded,
    super.key,
  });

  /// Text controller owned by the parent view.
  final TextEditingController controller;

  /// Whether a send is in progress — disables the send button when true.
  final bool isSending;

  /// Whether the agent is currently processing — shows stop button when true.
  /// When true, both send and stop buttons are visible simultaneously.
  final bool awaitingResponse;

  /// Whether the input is fully disabled (e.g. pending question/permission).
  /// When true, the TextField is read-only and the bar is visually dimmed.
  final bool disabled;

  /// Whether attachment uploads are in progress. When true, a progress
  /// indicator overlays each attachment preview tile.
  final bool isUploading;

  /// Number of messages currently queued for delivery after the agent finishes.
  /// When greater than zero, a badge is shown above the input field.
  final int queuedCount;

  /// Optional focus node passed from the parent. Falls back to an internal one.
  final FocusNode? focusNode;

  /// Callback fired when the send button is tapped or Enter is pressed.
  final VoidCallback? onSend;

  /// Callback fired when the stop button is tapped during agent processing.
  final VoidCallback? onStop;

  /// Callback fired when the user requests to cancel all queued messages.
  /// Reserved for future use — not yet wired to a UI element.
  final VoidCallback? onCancelQueue;

  /// Callback fired whenever the pending attachment list changes.
  /// Receives the updated full list after each add or remove.
  final ValueChanged<List<PlatformFile>>? onAttachmentsChanged;

  /// Callback fired with only the newly added files after a pick operation.
  /// Used to trigger immediate upload without re-uploading existing files.
  final ValueChanged<List<PlatformFile>>? onFilesAdded;

  @override
  State<ChatInputBar> createState() => ChatInputBarState();
}

/// Public state class so callers can hold a [GlobalKey<ChatInputBarState>]
/// and call [addAttachments], [validateAndAddAttachments], [clearAttachments].
class ChatInputBarState extends State<ChatInputBar> {
  late final FocusNode _internalFocusNode;
  bool _isEmpty = true;

  /// Current pending attachments shown in the preview strip.
  final List<PlatformFile> _attachments = [];

  // ---------------------------------------------------------------------------
  // Limits
  // ---------------------------------------------------------------------------

  static const int _maxFiles = 4;
  static const int _maxBytes = 5 * 1024 * 1024; // 5 MB

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
  // Public API
  // ---------------------------------------------------------------------------

  /// Appends [files] to the attachment list without validation.
  /// Triggers a rebuild, fires [onAttachmentsChanged], and fires
  /// [onFilesAdded] with only the newly added files.
  void addAttachments(List<PlatformFile> files) {
    setState(() => _attachments.addAll(files));
    widget.onAttachmentsChanged?.call(List.unmodifiable(_attachments));
    widget.onFilesAdded?.call(files);
  }

  /// Validates [files] for count and size limits, then adds them if valid.
  ///
  /// Shows a [SnackBar] and aborts if:
  /// - Total would exceed [_maxFiles] files.
  /// - Any single file exceeds [_maxBytes].
  void validateAndAddAttachments(List<PlatformFile> files) {
    if (_attachments.length + files.length > _maxFiles) {
      _showError(
        trans('chat.attachment_limit_count', {'max': _maxFiles.toString()}),
      );
      return;
    }

    for (final file in files) {
      if (file.size > _maxBytes) {
        _showError(trans('chat.attachment_limit_size', {'max': '5'}));
        return;
      }
    }

    addAttachments(files);
  }

  /// Removes all pending attachments and fires [onAttachmentsChanged].
  void clearAttachments() {
    setState(() => _attachments.clear());
    widget.onAttachmentsChanged?.call([]);
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

  bool get _canSend =>
      (!_isEmpty || _attachments.isNotEmpty) &&
      !widget.isSending &&
      !widget.isUploading &&
      !widget.disabled;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    validateAndAddAttachments(result.files);
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
    widget.onAttachmentsChanged?.call(List.unmodifiable(_attachments));
  }

  void _handleSend() {
    widget.onSend?.call();
    clearAttachments();
  }

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
      _handleSend();
    }

    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  bool _isPdf(PlatformFile file) => file.name.toLowerCase().endsWith('.pdf');

  /// Builds an image preview for a picked file.
  ///
  /// Uses [Image.memory] from local bytes when available (web / after read),
  /// falling back to a generic image icon placeholder.
  Widget _buildImagePreview(PlatformFile file) {
    if (file.bytes != null) {
      return Image.memory(
        file.bytes!,
        fit: BoxFit.cover,
        width: 56,
        height: 56,
      );
    }

    return WIcon(Icons.image_rounded, className: 'text-2xl text-slate-400');
  }

  Widget _buildAttachmentPreview(PlatformFile file, int index) {
    final isPdf = _isPdf(file);

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Thumbnail or PDF icon tile — real image preview for non-PDFs
          WDiv(
            className: '''
                w-14 h-14 rounded-lg overflow-hidden
                bg-slate-100 dark:bg-slate-800
                flex items-center justify-center
                ''',
            child: isPdf
                ? WIcon(
                    Icons.picture_as_pdf_rounded,
                    className: 'text-2xl text-red-500',
                  )
                : _buildImagePreview(file),
          ),

          // Upload progress overlay — shown while uploads are in progress
          if (widget.isUploading)
            WDiv(
              className: '''
                  w-14 h-14 rounded-lg
                  bg-black/40
                  flex items-center justify-center
                  ''',
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),

          // Remove button — top-right corner
          Positioned(
            top: -4,
            right: -4,
            child: WAnchor(
              onTap: () => _removeAttachment(index),
              child: WDiv(
                className: '''
                    w-5 h-5 rounded-full
                    bg-slate-700 dark:bg-slate-600
                    flex items-center justify-center
                    ''',
                child: WIcon(Icons.close, className: 'text-xs text-white'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentStrip() {
    return WDiv(
      className: 'flex flex-row gap-2 pb-2 overflow-x-auto',
      children: [
        for (var i = 0; i < _attachments.length; i++)
          _buildAttachmentPreview(_attachments[i], i),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WDiv(
      className:
          '''
        w-full bg-white dark:bg-slate-900 px-3 py-3.5
        border-t border-slate-200 dark:border-slate-700
        ${widget.disabled ? 'opacity-50' : ''}
      ''',
      children: [
        // Queue count badge — shown above the input row when messages are queued
        if (widget.queuedCount > 0)
          WDiv(
            className: 'px-3 py-1 mb-2',
            child: WText(
              trans('conversation_chat.queue_count', {
                'count': widget.queuedCount.toString(),
              }),
              className: 'text-xs text-amber-600 dark:text-amber-400',
            ),
          ),

        // Attachment preview strip — shown above the input row when files are selected
        if (_attachments.isNotEmpty) _buildAttachmentStrip(),

        WDiv(
          className: 'flex flex-row gap-3 items-center axis-max',
          children: [
            // Attachment button — opens file picker
            WAnchor(
              onTap: widget.disabled ? null : _pickFiles,
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
                readOnly: widget.disabled,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 6,
                style: TextStyle(
                  fontFamily: 'AlbertSans',
                  fontSize: 14,
                  color: WindTheme.dataOf(
                    context,
                  ).getColor('slate', isDark ? 100 : 800),
                ),
                decoration: InputDecoration.collapsed(
                  hintText: widget.disabled
                      ? trans('conversation_chat.input_disabled_hint')
                      : trans('conversation_chat.placeholder'),
                  hintStyle: TextStyle(
                    fontFamily: 'AlbertSans',
                    fontSize: 14,
                    color: WindTheme.dataOf(context).getColor('slate', 400),
                  ),
                ),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ),

            // Send button — always visible; enabled when there is text and not
            // in a transient sending state, regardless of awaitingResponse.
            WAnchor(
              onTap: _canSend ? _handleSend : null,
              child: WDiv(
                className: _canSend
                    ? 'w-10 h-10 rounded-full bg-amber-400 flex items-center justify-center'
                    : 'w-10 h-10 rounded-full bg-slate-300 dark:bg-slate-600 flex items-center justify-center',
                child: WIcon(Icons.send, className: 'text-base text-slate-900'),
              ),
            ),

            // Stop button — only visible while the agent is executing
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
              ),
          ],
        ),
      ],
    );
  }
}
