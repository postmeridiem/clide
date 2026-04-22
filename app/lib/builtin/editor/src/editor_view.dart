import 'dart:async';

import 'package:clide/clide.dart';
import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/kernel/src/syntax/tree_sitter_service.dart';
import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'editor_controller.dart';
import 'syntax_text_controller.dart';

/// Tier-2 editor tab. One tab — the content reflects the daemon's
/// active buffer. Multi-file tabs live in the workspace-slot plan but
/// aren't in Tier 2's scope; opening a new file swaps this view's
/// content.
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
  final TreeSitterService _syntax = TreeSitterService();
  late final SyntaxTextController _text;
  late final FocusNode _focus;
  String? _lastRemoteContent;

  @override
  void initState() {
    super.initState();
    _text = SyntaxTextController(syntax: _syntax);
    _focus = FocusNode();
    _text.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = EditorController(ipc: kernel.ipc, events: kernel.events)
      ..addListener(_onControllerChanged);
    unawaited(_controller!.hydrate());
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    _focus.dispose();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _syntax.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final c = _controller!;
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
    setState(() {}); // subtitle refresh
  }

  void _onTextChanged() {
    final c = _controller;
    if (c == null || c.activeId == null) return;
    final value = _text.value;
    if (value.text == c.content &&
        value.selection.baseOffset == c.selection.start &&
        value.selection.extentOffset == c.selection.end) {
      return;
    }
    _lastRemoteContent = value.text;
    c.pushLocalEdit(
      newContent: value.text,
      newSelection: Selection(
        start: value.selection.start < 0
            ? value.text.length
            : value.selection.start,
        end: value.selection.end < 0
            ? value.text.length
            : value.selection.end,
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCmd = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isCmd && event.logicalKey == LogicalKeyboardKey.keyS) {
      unawaited(_controller?.save());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
        final title = c.activePath ?? 'editor';
        final subtitle = c.activeId == null
            ? 'no buffer · use `clide open <path>` or pick a file in the tree'
            : '${c.activeId} · ${c.dirty ? 'modified' : 'saved'}'
                '${c.error == null ? '' : ' · ${c.error}'}';

        return ClidePaneChrome(
          title: title,
          subtitle: subtitle,
          child: c.activeId == null
              ? const Center(
                  child: ClideText(
                    'Open a file to begin editing.',
                    muted: true,
                  ),
                )
              : Focus(
                  onKeyEvent: _onKey,
                  child: _TextBody(
                    controller: _text,
                    focus: _focus,
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
    required this.background,
    required this.foreground,
    required this.accent,
  });

  final TextEditingController controller;
  final FocusNode focus;
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
