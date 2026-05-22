/// Native input composer for the Claude pane (epic T-132, T-138).
///
/// A no-Material [EditableText] (D-7) below the [ConversationView].
/// Enter submits; Shift+Enter inserts a newline. Submitted text is sent
/// to Claude's tmux session via `pane.write` (the same CLI verb the
/// terminal pane uses — D-6 parity), so there's no Claude-only input
/// path. File/image paste (the `@path` mechanism) is layered on top via
/// the paste-intent override; plain text paste falls through to the
/// default.
library;

import 'dart:async';

import 'package:clide/kernel/src/theme/controller.dart';
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

  /// Called with the raw composed text when the user submits. The text
  /// is not yet PTY-encoded — the pane wraps it with [encodeClaudeInput].
  final void Function(String text) onSubmit;

  final bool enabled;
  final String hint;

  /// Optional override of paste handling: given nothing, returns the
  /// text to insert at the cursor (e.g. `@/path/to/file`) or null to
  /// fall back to the default plain-text paste. Injected so the pane can
  /// wire in native file/image clipboard support and tests can fake it.
  final Future<String?> Function()? pasteResolver;

  @override
  State<ClaudeComposer> createState() => _ClaudeComposerState();
}

class _ClaudeComposerState extends State<ClaudeComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

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
    if (text.trim().isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  Future<void> _handlePaste() async {
    final resolver = widget.pasteResolver;
    if (resolver != null) {
      final inserted = await resolver();
      if (inserted != null) {
        if (!mounted) return;
        _insertAtCursor(inserted);
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
    final tokens = ClideTheme.of(context).surface;
    final hasText = _controller.text.isNotEmpty;
    final fg = widget.enabled ? tokens.globalForeground : tokens.globalTextMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: tokens.globalBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Semantics(
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
                    cursorColor: tokens.globalFocus,
                    backgroundCursorColor: tokens.globalTextMuted,
                    maxLines: 8,
                    minLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
