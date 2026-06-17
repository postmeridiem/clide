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

import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/clipboard_paste.dart';
import 'package:clide/builtin/claude/src/image_thumbnail.dart';
import 'package:clide/builtin/claude/src/permission_mode_control.dart';
import 'package:clide/builtin/claude/src/running_indicator.dart';
import 'package:clide/builtin/claude/src/slash_commands.dart';
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
    this.slashCommandsResolver,
    this.onInterrupt,
    this.busy = false,
    this.onCycleMode,
    this.permissionMode,
    this.onSetPermissionMode,
    this.initialValue,
    this.onDraftChanged,
    this.history = const [],
    this.focusNode,
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

  /// Source of the slash-command list for the typeahead. Defaults to the
  /// app-wide [ClaudeConfig]; injected in tests (T-152).
  final Iterable<String> Function()? slashCommandsResolver;

  /// Interrupt the running turn — fired by the Stop button and by Escape
  /// (when the typeahead is closed). The escape hatch for a runaway turn.
  final VoidCallback? onInterrupt;

  /// Cycle the session's permission mode — fired by Ctrl/Cmd+M while the
  /// composer is focused (T-226). Intercepted here (not a global keymap
  /// binding) so it targets this pane's session. Null disables the chord.
  final VoidCallback? onCycleMode;

  /// Whether a turn is in flight; shows the Stop affordance.
  final bool busy;

  /// Current permission mode (T-275). When set together with
  /// [onSetPermissionMode], an icon-only mode control trails the text box,
  /// opening a menu to switch mode. Null hides the control.
  final String? permissionMode;

  /// Set a specific permission mode from the trailing control's menu (T-275).
  final ValueChanged<String>? onSetPermissionMode;

  /// Seed value (text + selection) the composer mounts with — the
  /// persisted per-session draft (T-228). The composer restores this on
  /// init so an in-progress message survives the composer being torn down
  /// and rebuilt (e.g. a permission prompt taking its place, D-78).
  final TextEditingValue? initialValue;

  /// Reports every change to the composer's value so the owner can persist
  /// the draft. Fires with an empty value on submit/clear (T-228).
  final ValueChanged<TextEditingValue>? onDraftChanged;

  /// Previously-submitted prompts for this session, oldest-first. Up/Down
  /// walk this when the caret is on the first/last line (T-163). Owned by
  /// the pane (per session); the composer only reads it.
  final List<String> history;

  /// Optional externally-owned focus node, so the pane can focus the
  /// composer (e.g. on a background tap, T-227). When provided the owner
  /// disposes it; otherwise the composer creates and disposes its own.
  final FocusNode? focusNode;

  @override
  State<ClaudeComposer> createState() => _ClaudeComposerState();
}

class _ClaudeComposerState extends State<ClaudeComposer> {
  final TextEditingController _controller = TextEditingController();
  late final bool _ownsFocus = widget.focusNode == null;
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  final List<ComposerAttachment> _attachments = [];

  // Slash typeahead state (T-152). The popover is a ClideTypeahead driven by
  // [_suggestions] (D-88); [_slashNav] is its highlight, advanced from _onKey
  // while the EditableText keeps focus.
  SlashQuery? _query;
  List<String> _suggestions = const [];
  final ClideMenuListController _slashNav = ClideMenuListController(isSelectable: (_) => true, length: 0);

  // Prompt-history navigation (T-163). _historyIndex is null when editing
  // the live draft; otherwise it indexes [widget.history]. _stash holds the
  // draft we were typing before stepping into history, restored on stepping
  // back past the newest entry. _applyingHistory suppresses the draft report
  // so previewing history entries doesn't overwrite the persisted draft.
  int? _historyIndex;
  TextEditingValue? _stash;
  bool _applyingHistory = false;

  @override
  void initState() {
    super.initState();
    // Restore the persisted draft (text + caret) before wiring listeners,
    // so seeding doesn't echo back through onDraftChanged (T-228).
    final seed = widget.initialValue;
    if (seed != null && seed.text.isNotEmpty) {
      _controller.value = seed;
    }
    // Drive key handling whether the node is ours or the pane's (T-227).
    _focus.onKeyEvent = _onKey;
    _controller.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _slashNav.dispose();
    _controller.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    _controller.dispose();
    if (_ownsFocus) {
      _focus.dispose();
    } else {
      _focus.onKeyEvent = null; // detach our handler from the pane-owned node
    }
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
    if (!_applyingHistory) {
      // A real edit (user typed) while previewing history commits to it —
      // leave navigation and treat the text as the new draft.
      _historyIndex = null;
      _stash = null;
      widget.onDraftChanged?.call(_controller.value);
    }
    _syncTypeahead();
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _closeTypeahead();
  }

  Iterable<String> _commands() {
    // Always union the clide-owned commands (/clear, /resume, /fork) onto the
    // command source — whether that's a caller-supplied resolver or the default
    // ClaudeConfig probe — since the CLI probe never advertises them (T-162).
    // The Set literal de-dupes (e.g. 'clear' present in both).
    final base = widget.slashCommandsResolver?.call() ?? activeClaudeConfig?.slashCommands ?? const <String>[];
    return {...base, ...kClideOwnedCommands};
  }

  /// Recompute the active slash query + suggestions from the current text and
  /// caret, opening/updating/closing the typeahead overlay accordingly.
  void _syncTypeahead() {
    if (!widget.enabled) return;
    final sel = _controller.selection;
    final q = sel.isCollapsed && sel.baseOffset >= 0 ? activeSlashQuery(_controller.text, sel.baseOffset) : null;
    final suggestions = q == null ? const <String>[] : filterSlashCommands(q.query, _commands());
    if (q == null || suggestions.isEmpty) {
      _closeTypeahead();
      return;
    }
    // _onTextChanged (our only caller) already setState'd; just update state +
    // the highlight, and ClideTypeahead opens the popover from [_suggestions].
    _query = q;
    _suggestions = suggestions;
    _slashNav.length = suggestions.length;
    _slashNav.setHighlight(0);
  }

  void _closeTypeahead() {
    if (_query == null && _suggestions.isEmpty) return;
    if (mounted) {
      setState(() {
        _query = null;
        _suggestions = const [];
      });
    } else {
      _query = null;
      _suggestions = const [];
    }
    _slashNav.length = 0;
  }

  void _moveSelection(int delta) => delta > 0 ? _slashNav.moveNext() : _slashNav.movePrev();

  void _completeSelected() {
    final i = _slashNav.highlighted;
    if (i < 0 || i >= _suggestions.length) return;
    _complete(_suggestions[i]);
  }

  /// Replace the active `/query` with [command] (keyboard Tab/Enter or a mouse
  /// click on a typeahead row). The replacement re-runs _syncTypeahead via the
  /// controller listener; the caret now sits after a space, so the query closes.
  void _complete(String command) {
    final q = _query;
    if (q == null) return;
    final r = completeSlash(_controller.text, q, command);
    _controller.value = TextEditingValue(
      text: r.text,
      selection: TextSelection.collapsed(offset: r.cursor),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    // Ctrl/Cmd+M: cycle the session's permission mode (T-226). Intercepted
    // here so it targets this pane. (Shift+Tab — the CLI chord — is off the
    // table: it's a real a11y focus-traversal binding.)
    final mod = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    if (mod && e.logicalKey == LogicalKeyboardKey.keyM && widget.onCycleMode != null) {
      widget.onCycleMode!();
      return KeyEventResult.handled;
    }
    // Escape: dismiss the typeahead if open, otherwise interrupt the running
    // turn — the escape hatch from a runaway (D-78).
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      if (_suggestions.isNotEmpty) {
        _closeTypeahead();
        return KeyEventResult.handled;
      }
      if (widget.onInterrupt != null) {
        widget.onInterrupt!();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (_suggestions.isEmpty) {
      // Typeahead closed → Up/Down recall prompt history, but only once the
      // caret reaches the first/last line so multi-line editing still works
      // line-by-line first (T-163, Claude-CLI-style).
      switch (e.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          if (_caretOnFirstLine() && _historyPrev()) return KeyEventResult.handled;
          return KeyEventResult.ignored;
        case LogicalKeyboardKey.arrowDown:
          if (_historyIndex != null && _caretOnLastLine()) {
            _historyNext();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
      }
      return KeyEventResult.ignored;
    }
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _moveSelection(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _moveSelection(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.tab:
        _completeSelected();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // -- Prompt history (T-163) -------------------------------------------------

  bool _caretOnFirstLine() {
    final sel = _controller.selection;
    if (!sel.isCollapsed || sel.baseOffset < 0) return false;
    return !_controller.text.substring(0, sel.baseOffset).contains('\n');
  }

  bool _caretOnLastLine() {
    final sel = _controller.selection;
    if (!sel.isCollapsed || sel.baseOffset < 0) return false;
    return !_controller.text.substring(sel.baseOffset).contains('\n');
  }

  /// Step to the previous (older) history entry, stashing the live draft on
  /// first entry. Returns false only when there's no history to walk.
  bool _historyPrev() {
    final h = widget.history;
    if (h.isEmpty) return false;
    if (_historyIndex == null) {
      _stash = _controller.value;
      _historyIndex = h.length - 1;
    } else if (_historyIndex! > 0) {
      _historyIndex = _historyIndex! - 1;
    }
    // else: already at the oldest — consume the key, stay put.
    _applyHistory(h[_historyIndex!]);
    return true;
  }

  /// Step to the next (newer) entry; stepping past the newest restores the
  /// stashed draft and leaves history navigation.
  void _historyNext() {
    final h = widget.history;
    final idx = _historyIndex;
    if (idx == null) return;
    if (idx < h.length - 1) {
      _historyIndex = idx + 1;
      _applyHistory(h[_historyIndex!]);
    } else {
      _historyIndex = null;
      _applyValue(_stash ?? const TextEditingValue());
      _stash = null;
    }
  }

  void _applyHistory(String text) => _applyValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );

  /// Set the controller without it being treated as a user edit (so the
  /// preview doesn't overwrite the persisted draft or exit navigation).
  void _applyValue(TextEditingValue v) {
    _applyingHistory = true;
    _controller.value = v;
    _applyingHistory = false;
  }

  void _submit() {
    if (!widget.enabled) return;
    final text = _controller.text;
    final tokens = _attachments.map((a) => a.pathToken);
    if (text.trim().isEmpty && _attachments.isEmpty) return;
    // Typed text first, then the attachment @path references.
    final message = [if (text.trim().isNotEmpty) text, ...tokens].join(' ');
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
    final theme = ClideSettings.theme.of(context).surface;
    final hasText = _controller.text.isNotEmpty;
    final fg = widget.enabled ? theme.globalForeground : theme.globalTextMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: ClideTypeahead(
        suggestions: _suggestions,
        onSelect: _complete,
        navController: _slashNav,
        formatLabel: (c) => '/$c',
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
              // Running turn → an always-reachable Stop (also bound to Escape).
              if (widget.busy && widget.onInterrupt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const RunningIndicator(),
                      const Spacer(),
                      ClideButton(
                        label: 'Stop  ⎋',
                        variant: ClideButtonVariant.primary,
                        onPressed: widget.onInterrupt,
                        semanticHint: 'Interrupt the running turn (Escape)',
                      ),
                    ],
                  ),
                ),
              if (_attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [for (final a in _attachments) _chip(theme, a)]),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
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
                              if (!hasText) Positioned(left: 0, top: 0, right: 0, child: ClideText(widget.hint, muted: true, fontSize: clideFontBody)),
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
                  ),
                  if (widget.permissionMode != null && widget.onSetPermissionMode != null) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: PermissionModeControl(mode: widget.permissionMode!, onSelect: widget.onSetPermissionMode!),
                    ),
                  ],
                ],
              ),
            ],
          ),
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
            child: ClideText(a.fileName, fontSize: clideFontSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                child: ClideIcon(PhosphorIcons.byName('x'), size: 12, color: theme.globalTextMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipLeading(SurfaceTokens theme, ComposerAttachment a) {
    // A readable preview (not the old 28px speck) that opens the full image in
    // the lightbox on click — the same thumbnail the conversation log uses
    // (T-236/T-254).
    if (a.isImage) {
      return ImageThumbnail(path: a.path, size: 44);
    }
    return ClideIcon(PhosphorIcons.byName('file-text'), size: 18, color: theme.globalTextMuted);
  }
}
