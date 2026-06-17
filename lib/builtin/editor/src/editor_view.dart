import 'dart:async';

import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/syntax/tree_sitter_service.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'editor_controller.dart';
import 'syntax_text_controller.dart';
import 'vim_edit_ops.dart';

/// Tier-2 editor pane. Shows one tab per open buffer via the shared
/// [MultitabPane] (the same strip the Claude pane uses); the body
/// reflects the daemon's active buffer. The daemon (`EditorRegistry`)
/// is the source of truth for which buffers are open and which is
/// active — the local [MultitabController] is reconciled from it, and
/// tab gestures (select / close) are routed back as `editor.activate`
/// / `editor.close`.
///
/// Uses Flutter's low-level `EditableText` so we stay off Material
/// per D-007. Owning more of the editor stack (line numbers, gutter,
/// syntax highlighting) lands in later tiers; Tier 2 is plain text.
class EditorView extends StatefulWidget {
  const EditorView({super.key});

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  EditorController? _controller;
  final MultitabController<String> _tabs = MultitabController<String>();
  final TreeSitterService _syntax = TreeSitterService.shared;
  late final SyntaxTextController _text;
  late final FocusNode _focus;
  String? _lastRemoteContent;

  /// Vim sequence matcher (built once the kernel is available) + the
  /// yank register. Active only while a `vim.*` scope flag is set; under
  /// non-Vim presets the editor types normally (T-206).
  SequenceMatcher? _matcher;
  VimRegister _register = VimRegister.empty;
  KeymapService? _keymap;

  /// Guards the controller→tabstrip reconcile so the tabstrip's own
  /// change notifications (from us mutating it) don't bounce back as
  /// daemon calls.
  bool _applyingRemote = false;

  @override
  void initState() {
    super.initState();
    _text = SyntaxTextController(syntax: _syntax);
    _focus = FocusNode();
    _focus.addListener(_onFocusChanged);
    _text.addListener(_onTextChanged);
    _tabs.addListener(_onTabsChanged);
  }

  /// Publish `editor.focused` so non-editor panes can guard their vim nav
  /// bindings (`!editor.focused`) — when the editor holds focus, j/k/h/l/gg/G
  /// stay buffer motions; when a pane holds focus they become nav (T-406).
  void _onFocusChanged() => _keymap?.setScopeFlag('editor.focused', _focus.hasFocus);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = EditorController(ipc: kernel.ipc, events: kernel.events)..addListener(_onControllerChanged);
    _keymap = kernel.keymap;
    _matcher = SequenceMatcher(keymap: () => kernel.keymap.keymap ?? Keymap(const []), context: () => kernel.keymap.scope);
    // Rebuild when the Vim mode flips so the editor toggles read-only.
    kernel.keymap.addListener(_onModeChanged);
    unawaited(_controller!.hydrate());
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _tabs.removeListener(_onTabsChanged);
    _tabs.dispose();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _keymap?.removeListener(_onModeChanged);
    _keymap?.clearScopeFlag('editor.focused');
    super.dispose();
  }

  void _onModeChanged() {
    if (mounted) setState(() {});
  }

  /// True while a `vim.*` command mode (normal/visual) is active — the
  /// editor is read-only then, so printable keys delivered over the
  /// TextInput channel can't type while motions drive the buffer (T-206).
  bool get _vimCommandMode {
    final scope = _keymap?.scope ?? const <String, bool>{};
    return scope['vim.normal'] == true || scope['vim.visual'] == true;
  }

  void _onControllerChanged() {
    final c = _controller!;
    _syncTabs(c);
    _text.updatePath(c.activePath);
    final sel = TextSelection(baseOffset: c.selection.start.clamp(0, c.content.length), extentOffset: c.selection.end.clamp(0, c.content.length));
    if (c.content != _lastRemoteContent) {
      _lastRemoteContent = c.content;
      _text.removeListener(_onTextChanged);
      _text.value = TextEditingValue(text: c.content, selection: sel);
      _text.addListener(_onTextChanged);
    } else if (sel != _text.value.selection) {
      // Selection-only change from an external setSelection (ex-line `:N` goto,
      // find-in-files line jump on the already-active buffer) — content is
      // unchanged, so move just the caret. The focused field scrolls it into
      // view (T-407).
      _text.removeListener(_onTextChanged);
      _text.value = _text.value.copyWith(selection: sel);
      _text.addListener(_onTextChanged);
    }
    setState(() {}); // tab/title refresh
  }

  /// Reconcile the local tab strip to match the daemon's open-buffer
  /// list + active selection. Membership and order follow the daemon;
  /// titles carry a dirty marker.
  void _syncTabs(EditorController c) {
    _applyingRemote = true;
    final bufs = c.buffers;
    final liveIds = {for (final b in bufs) b.id};
    for (final e in _tabs.entries) {
      if (!liveIds.contains(e.id)) _tabs.remove(e.id);
    }
    for (final b in bufs) {
      final title = _tabTitle(b);
      final existing = _tabs.entries.where((e) => e.id == b.id).toList();
      if (existing.isEmpty) {
        _tabs.add(MultitabEntry<String>(id: b.id, title: title, payload: b.id), activate: false);
      } else if (existing.first.title != title) {
        _tabs.replace(b.id, MultitabEntry<String>(id: b.id, title: title, payload: b.id));
      }
    }
    final act = c.activeId;
    if (act != null && _tabs.activeId != act) _tabs.activate(act);
    _applyingRemote = false;
  }

  /// User tapped a tab. The tab strip already updated its local active
  /// selection; mirror that choice to the daemon.
  void _onTabsChanged() {
    if (_applyingRemote) return;
    final id = _tabs.activeId;
    if (id != null && id != _controller?.activeId) {
      unawaited(_controller?.activate(id) ?? Future.value());
    }
  }

  String _tabTitle(OpenBuffer b) {
    final name = b.path.split('/').last;
    return b.dirty ? '$name •' : name;
  }

  void _onTextChanged() {
    final c = _controller;
    if (c == null || c.activeId == null) return;
    final value = _text.value;
    if (value.text == c.content && value.selection.baseOffset == c.selection.start && value.selection.extentOffset == c.selection.end) {
      return;
    }
    _lastRemoteContent = value.text;
    c.pushLocalEdit(
      newContent: value.text,
      newSelection: Selection(
        start: value.selection.start < 0 ? value.text.length : value.selection.start,
        end: value.selection.end < 0 ? value.text.length : value.selection.end,
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final hw = HardwareKeyboard.instance;

    // Save works in every mode.
    final isCmd = hw.isMetaPressed || hw.isControlPressed;
    if (isCmd && event.logicalKey == LogicalKeyboardKey.keyS) {
      unawaited(_controller?.save());
      return KeyEventResult.handled;
    }

    // Tab indents per `.editorconfig` (T-29) — but only when the config has an
    // opinion, otherwise leave Flutter's default (focus traversal) alone. Skip
    // in Vim command mode, where keys drive motions.
    if (event.logicalKey == LogicalKeyboardKey.tab && !isCmd && !hw.isAltPressed && !_vimCommandMode) {
      final unit = _controller?.settings.indentUnit;
      if (unit != null) {
        _indent(unit, dedent: hw.isShiftPressed);
        return KeyEventResult.handled;
      }
    }

    final kernel = ClideKernel.of(context);
    final scope = kernel.keymap.scope;
    final inNormal = scope['vim.normal'] == true;
    final inVisual = scope['vim.visual'] == true;
    final chord = KeyChord.fromKeyEvent(event, hw);
    if (chord == null) return KeyEventResult.ignored;

    if (!inNormal && !inVisual) {
      // Insert mode (or non-Vim preset): type normally, but still let a
      // mode-change chord like Esc flip back to normal.
      final intent = kernel.keymap.keymap?.resolve(chord, scope);
      if (intent is InvokeCommandIntent && intent.commandId.startsWith('vim.mode.')) {
        unawaited(kernel.commands.execute(intent.commandId));
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Normal / visual mode. Ctrl/Alt/Meta chords are app shortcuts
    // (palette, find, …) — let them bubble to the global handler. Bare
    // keys and Shift chords (Vim's capitals: G, D, A, P, $) drive the
    // matcher and never reach text input.
    if (chord.modifiers.any((m) => m != KeyModifier.shift)) {
      return KeyEventResult.ignored;
    }

    final r = _matcher!.feed(chord);
    switch (r.outcome) {
      case SeqOutcome.pending:
      case SeqOutcome.unmatched:
        // Swallow: a partial sequence, or a key Vim ignores in this mode.
        return KeyEventResult.handled;
      case SeqOutcome.fired:
        _dispatchVim(r.intent!, r.count, kernel, visual: inVisual);
        return KeyEventResult.handled;
    }
  }

  /// Apply one indent step at the caret per the resolved settings (T-29).
  /// [unit] is the text a Tab inserts (spaces or a tab); [dedent] (Shift+Tab)
  /// instead strips up to one unit of leading whitespace from the caret's line.
  /// Writes through [_text] so `_onTextChanged` persists it to the daemon.
  void _indent(String unit, {required bool dedent}) {
    final value = _text.value;
    final sel = value.selection;
    if (!sel.isValid) return;
    final text = value.text;

    if (!dedent) {
      final newText = text.replaceRange(sel.start, sel.end, unit);
      _text.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + unit.length),
      );
      return;
    }

    // Dedent: remove leading whitespace from the start of the caret's line.
    final caret = sel.baseOffset < 0 ? text.length : sel.baseOffset;
    final lineStart = text.lastIndexOf('\n', caret - 1) + 1; // 0 when on the first line
    var remove = 0;
    if (unit == '\t') {
      if (lineStart < text.length && text[lineStart] == '\t') remove = 1;
    } else {
      while (remove < unit.length && lineStart + remove < text.length && text[lineStart + remove] == ' ') {
        remove++;
      }
    }
    if (remove == 0) return;
    final newText = text.replaceRange(lineStart, lineStart + remove, '');
    int shift(int off) => off > lineStart ? (off - remove).clamp(lineStart, newText.length) : off;
    _text.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: shift(sel.baseOffset), extentOffset: shift(sel.extentOffset)),
    );
  }

  void _dispatchVim(Intent intent, int count, KernelServices kernel, {required bool visual}) {
    if (intent is! InvokeCommandIntent) {
      // A typed app intent the matcher fired (e.g. the ex-line `:` open or ZZ).
      // The editor only owns editor.vim.* / mode commands; bubble anything else
      // to the app-root Actions so it reaches its global handler (T-407).
      Actions.maybeInvoke(context, intent);
      return;
    }
    final id = intent.commandId;
    if (!id.startsWith('editor.vim.')) {
      // Mode change (vim.mode.*) or any other command.
      unawaited(kernel.commands.execute(id));
      return;
    }
    final result = applyVim(id, _text.value, register: _register, visual: visual, count: count);
    if (result.register != null) _register = result.register!;
    _text.value = result.value; // _onTextChanged persists content + caret
    if (result.enterInsert) {
      unawaited(kernel.commands.execute('vim.mode.insert'));
    } else if (visual) {
      // A visual range op (d/y/c) returns to normal mode; motions that
      // merely extend the selection stay in visual.
      const rangeOps = {VimAction.visualDelete, VimAction.visualYank, VimAction.visualChange};
      if (rangeOps.contains(id)) unawaited(kernel.commands.execute('vim.mode.normal'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final tokens = ClideTheme.of(context).surface;
    _text.tokens = tokens;
    if (c == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.buffers.isEmpty) {
          return ClidePaneChrome(
            title: 'editor',
            subtitle: 'no buffer · use `clide open <path>` or pick a file in the tree',
            child: const Center(child: ClideText('Open a file to begin editing.', muted: true)),
          );
        }
        return MultitabPane<String>(
          controller: _tabs,
          allowReorder: false,
          onCloseRequested: (entry) => unawaited(c.closeBuffer(entry.id)),
          bodyBuilder: (context, _) => Focus(
            onKeyEvent: _onKey,
            child: _TextBody(
              controller: _text,
              focus: _focus,
              readOnly: _vimCommandMode,
              background: tokens.panelBackground,
              foreground: tokens.globalForeground,
              accent: tokens.globalFocus,
              rulerColumn: c.settings.maxLineLength,
            ),
          ),
        );
      },
    );
  }
}

class _TextBody extends StatelessWidget {
  const _TextBody({
    required this.controller,
    required this.focus,
    required this.readOnly,
    required this.background,
    required this.foreground,
    required this.accent,
    this.rulerColumn,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool readOnly;
  final Color background;
  final Color foreground;
  final Color accent;

  /// `max_line_length` from the resolved settings — draws a wrap-guide ruler at
  /// that column (T-29). Null hides it.
  final int? rulerColumn;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: foreground,
      fontSize: clideFontMono,
      fontFamily: ClideSettings.fonts.monoOf(context),
      fontFamilyFallback: clideMonoFamilyFallback,
    );
    final editable = EditableText(
      controller: controller,
      focusNode: focus,
      readOnly: readOnly,
      style: style,
      cursorColor: foreground,
      backgroundCursorColor: foreground.withAlpha(0x44),
      selectionColor: accent.withAlpha(0x55),
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      textAlign: TextAlign.start,
      showCursor: true,
    );
    return Semantics(
      label: 'editor text area',
      textField: true,
      multiline: true,
      child: ColoredBox(
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(8),
          // CustomPaint sizes to and paints behind the EditableText, so the
          // ruler shares the text's coordinate space (column 0 at the left edge).
          child: CustomPaint(
            painter: rulerColumn == null ? null : _RulerPainter(x: _charWidth(style) * rulerColumn!, color: foreground.withAlpha(0x22)),
            child: editable,
          ),
        ),
      ),
    );
  }

  /// Advance width of one monospace glyph in [style].
  static double _charWidth(TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }
}

/// A 1px vertical wrap-guide at [x] (content-relative), behind the text.
class _RulerPainter extends CustomPainter {
  const _RulerPainter({required this.x, required this.color});

  final double x;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.x != x || old.color != color;
}
