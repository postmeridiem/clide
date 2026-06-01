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
/// reflects the daemon's active buffer. The daemon ([EditorRegistry])
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
    _text.addListener(_onTextChanged);
    _tabs.addListener(_onTabsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = EditorController(ipc: kernel.ipc, events: kernel.events)..addListener(_onControllerChanged);
    _keymap = kernel.keymap;
    _matcher = SequenceMatcher(
      keymap: () => kernel.keymap.keymap ?? Keymap(const []),
      context: () => kernel.keymap.scope,
    );
    // Rebuild when the Vim mode flips so the editor toggles read-only.
    kernel.keymap.addListener(_onModeChanged);
    unawaited(_controller!.hydrate());
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    _focus.dispose();
    _tabs.removeListener(_onTabsChanged);
    _tabs.dispose();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _keymap?.removeListener(_onModeChanged);
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
    if (c.content != _lastRemoteContent) {
      _lastRemoteContent = c.content;
      final sel = TextSelection(
        baseOffset: c.selection.start.clamp(0, c.content.length),
        extentOffset: c.selection.end.clamp(0, c.content.length),
      );
      _text.removeListener(_onTextChanged);
      _text.value = TextEditingValue(text: c.content, selection: sel);
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

    // Normal / visual mode. Modified chords are app shortcuts (palette,
    // find, …) — let them bubble to the global handler. Bare keys drive
    // the Vim matcher and never reach text input.
    if (chord.modifiers.isNotEmpty) return KeyEventResult.ignored;

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

  void _dispatchVim(Intent intent, int count, KernelServices kernel, {required bool visual}) {
    if (intent is! InvokeCommandIntent) return;
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
            child: const Center(
              child: ClideText('Open a file to begin editing.', muted: true),
            ),
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
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool readOnly;
  final Color background;
  final Color foreground;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'editor text area',
      textField: true,
      multiline: true,
      child: ColoredBox(
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: EditableText(
            controller: controller,
            focusNode: focus,
            readOnly: readOnly,
            style: TextStyle(
              color: foreground,
              fontSize: clideFontMono,
              fontFamily: clideMonoFamily,
              fontFamilyFallback: clideMonoFamilyFallback,
            ),
            cursorColor: foreground,
            backgroundCursorColor: foreground.withAlpha(0x44),
            selectionColor: accent.withAlpha(0x55),
            maxLines: null,
            expands: true,
            keyboardType: TextInputType.multiline,
            textAlign: TextAlign.start,
            showCursor: true,
          ),
        ),
      ),
    );
  }
}
