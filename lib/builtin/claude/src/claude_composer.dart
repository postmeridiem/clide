/// Native input composer for the Claude pane (epic T-132, T-138).
///
/// A no-Material [EditableText] (D-7) below the [ConversationView].
/// Enter submits; Shift+Enter inserts a newline. The composed message
/// (typed text plus any attachment `@path` tokens) is handed to
/// [ClaudeComposer.onSubmit]; the pane delivers it to Claude. Pasted
/// files/images show as removable chips (T-142); plain text paste falls
/// through to the default.
library;

import 'dart:async';
import 'dart:io';

import 'package:clide/builtin/claude/src/clipboard_paste.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Encodes [text] for delivery to Claude's PTY via `pane.write`.
///
/// Single-line input is sent literally followed by a carriage return
/// (submit). Multi-line input is wrapped in bracketed-paste markers so
/// the embedded newlines are treated as pasted content rather than a
/// stream of submits, then a trailing CR submits the whole block.
String encodeClaudeInput(String text) {
  if (text.contains('\n')) {
    return '\x1b[200~$text\x1b[201~\r';
  }
  return '$text\r';
}

/// Intent fired when the user presses Enter (no modifiers) to submit.
class SubmitComposerIntent extends Intent {
  const SubmitComposerIntent();
}

class ClaudeComposer extends StatefulWidget {
  const ClaudeComposer({
    super.key,
    required this.onSubmit,
    this.enabled = true,
    this.hint = 'Message Claude…  (Enter to send · Shift+Enter for newline)',
    this.pasteResolver,
  });

  /// Called with the composed message (typed text plus attachment `@path`
  /// tokens) when the user submits. The pane delivers it to Claude.
  final void Function(String text) onSubmit;

  final bool enabled;
  final String hint;

  /// Optional override of paste handling: returns the attachments on the
  /// clipboard (files / images), or an empty list to fall back to the
  /// default plain-text paste. Injected so the pane can wire in native
  /// file/image clipboard support and tests can fake it.
  final Future<List<ComposerAttachment>> Function()? pasteResolver;

  @override
  State<ClaudeComposer> createState() => _ClaudeComposerState();
}

class _ClaudeComposerState extends State<ClaudeComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<ComposerAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _submit() {
    if (!widget.enabled) return;
    final text = _controller.text;
    final tokens = _attachments.map((a) => a.pathToken);
    if (text.trim().isEmpty && _attachments.isEmpty) return;
    // Typed text first, then the attachment @path references.
    final message = [
      if (text.trim().isNotEmpty) text,
      ...tokens,
    ].join(' ');
    widget.onSubmit(message);
    _controller.clear();
    setState(() => _attachments.clear());
  }

  Future<void> _handlePaste() async {
    final resolver = widget.pasteResolver;
    if (resolver != null) {
      final attachments = await resolver();
      if (attachments.isNotEmpty) {
        if (!mounted) return;
        setState(() => _attachments.addAll(attachments));
        return;
      }
    }
    // Fall back to the default plain-text paste.
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final clip = data?.text;
    if (clip != null && clip.isNotEmpty && mounted) {
      _insertAtCursor(clip);
    }
  }

  void _removeAttachment(ComposerAttachment attachment) {
    setState(() => _attachments.remove(attachment));
  }

  void _insertAtCursor(String insertion) {
    final value = _controller.value;
    final sel = value.selection;
    final base = sel.isValid ? sel : TextSelection.collapsed(offset: value.text.length);
    final newText = value.text.replaceRange(base.start, base.end, insertion);
    final caret = base.start + insertion.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ClideTheme.of(context).surface;
    final hasText = _controller.text.isNotEmpty;
    final fg = widget.enabled ? theme.globalForeground : theme.globalTextMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.globalBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final a in _attachments) _chip(theme, a)],
                ),
              ),
            Semantics(
              label: widget.hint,
              textField: true,
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.enter): SubmitComposerIntent(),
                  SingleActivator(LogicalKeyboardKey.numpadEnter): SubmitComposerIntent(),
                },
                child: Actions(
                  actions: {
                    SubmitComposerIntent: CallbackAction<SubmitComposerIntent>(
                      onInvoke: (_) {
                        _submit();
                        return null;
                      },
                    ),
                    PasteTextIntent: CallbackAction<PasteTextIntent>(
                      onInvoke: (_) {
                        unawaited(_handlePaste());
                        return null;
                      },
                    ),
                  },
                  child: Stack(
                    children: [
                      if (!hasText)
                        Positioned(
                          left: 0,
                          top: 0,
                          right: 0,
                          child: ClideText(widget.hint, muted: true, fontSize: clideFontBody),
                        ),
                      EditableText(
                        controller: _controller,
                        focusNode: _focus,
                        readOnly: !widget.enabled,
                        style: TextStyle(fontSize: clideFontBody, color: fg, height: 1.4),
                        cursorColor: theme.globalFocus,
                        backgroundCursorColor: theme.globalTextMuted,
                        maxLines: 8,
                        minLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One attachment chip: a thumbnail (images) or file icon (other types),
  /// the filename, and a remove × that cancels the attachment before send.
  Widget _chip(SurfaceTokens theme, ComposerAttachment a) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: theme.panelBackground,
        border: Border.all(color: theme.globalBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chipLeading(theme, a),
          const SizedBox(width: 6),
          Flexible(
            child: ClideText(
              a.fileName,
              fontSize: clideFontSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: 'Remove ${a.fileName}',
            child: GestureDetector(
              key: ValueKey('composer-remove-${a.path}'),
              onTap: () => _removeAttachment(a),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ClideIcon(PhosphorIcons.xMark, size: 12, color: theme.globalTextMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipLeading(SurfaceTokens theme, ComposerAttachment a) {
    const dim = 28.0;
    if (a.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(a.path),
          width: dim,
          height: dim,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ClideIcon(PhosphorIcons.image, size: 18, color: theme.globalTextMuted),
        ),
      );
    }
    return ClideIcon(PhosphorIcons.fileText, size: 18, color: theme.globalTextMuted);
  }
}
