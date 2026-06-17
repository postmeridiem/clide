/// The `/model` picker for the interaction zone (T-408, D-78): a bare
/// `/model` swaps this card in for the composer; picking an entry sends
/// `set_model` over the control channel and the composer returns. Esc
/// cancels. Like [ToolPromptCard], it lives in the composer zone — never
/// inline in the conversation.
///
/// Keyboard: number keys pick directly (CLI muscle memory, T-240), Up/Down
/// move the highlight, Enter picks the highlighted entry, Esc cancels.
library;

import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether [option] is the session's current model. Options carry aliases
/// (`sonnet`) or full ids while the status holds the full id
/// (`claude-sonnet-4-6`), so match on equality or alias containment.
bool modelOptionIsCurrent(ModelOption option, String? currentModel) {
  if (currentModel == null || option.value == 'default') return false;
  if (option.value == currentModel) return true;
  return currentModel.toLowerCase().contains(option.value.toLowerCase());
}

class ModelPickerCard extends StatefulWidget {
  const ModelPickerCard({
    super.key,
    required this.models,
    this.currentModel,
    required this.onPick,
    required this.onCancel,
    this.title = 'model',
    this.isCurrent = modelOptionIsCurrent,
  });

  /// Selectable entries, in display order. Callers pass [kFallbackModels]
  /// when the session hasn't reported its list yet.
  final List<ModelOption> models;

  /// The session's current model (full id), to mark the active entry.
  final String? currentModel;

  /// Called once with the picked [ModelOption.value].
  final void Function(String value) onPick;

  /// Called when the user dismisses the picker without choosing.
  final VoidCallback onCancel;

  /// Header label. The /effort picker reuses this card with its own title
  /// and an exact-match [isCurrent] (T-412).
  final String title;

  /// Marks the active entry. The model default ([modelOptionIsCurrent]) also
  /// alias-matches (`sonnet` ⊂ `claude-sonnet-4-6`); effort needs exact match
  /// (`high` would falsely match inside `xhigh`).
  final bool Function(ModelOption option, String? current) isCurrent;

  @override
  State<ModelPickerCard> createState() => _ModelPickerCardState();
}

class _ModelPickerCardState extends State<ModelPickerCard> {
  late int _highlight = _initialHighlight();

  int _initialHighlight() {
    for (var i = 0; i < widget.models.length; i++) {
      if (widget.isCurrent(widget.models[i], widget.currentModel)) return i;
    }
    return 0;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || !node.hasPrimaryFocus) return KeyEventResult.ignored;
    final hw = HardwareKeyboard.instance;
    if (hw.isControlPressed || hw.isAltPressed || hw.isMetaPressed) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlight = (_highlight + 1) % widget.models.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _highlight = (_highlight - 1 + widget.models.length) % widget.models.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      widget.onPick(widget.models[_highlight].value);
      return KeyEventResult.handled;
    }
    final digit = _digitOf(key);
    if (digit != null && digit >= 1 && digit <= widget.models.length) {
      widget.onPick(widget.models[digit - 1].value);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static int? _digitOf(LogicalKeyboardKey key) {
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    var i = digits.indexOf(key);
    if (i < 0) i = numpad.indexOf(key);
    return i < 0 ? null : i + 1;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          border: Border(top: BorderSide(color: tokens.statusInfo, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClideText(widget.title, fontSize: clideFontSmall, fontFamily: ClideSettings.fonts.monoOf(context), color: tokens.statusInfo),
                const Spacer(),
                ClideText(
                  '↑↓ · 1-${widget.models.length} · Enter · Esc',
                  fontSize: clideFontMeta,
                  fontFamily: ClideSettings.fonts.monoOf(context),
                  color: tokens.globalTextMuted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < widget.models.length; i++) _row(tokens, i),
            const SizedBox(height: 6),
            Row(
              children: [
                const Spacer(),
                ClideButton(label: 'cancel', variant: ClideButtonVariant.subtle, onPressed: widget.onCancel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(SurfaceTokens tokens, int i) {
    final m = widget.models[i];
    final current = widget.isCurrent(m, widget.currentModel);
    final highlighted = i == _highlight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClideButton(
        label: '${i + 1}. ${current ? '●' : '○'} ${m.displayName}${m.description.isEmpty ? '' : ' — ${m.description}'}',
        variant: highlighted ? ClideButtonVariant.primary : ClideButtonVariant.subtle,
        onPressed: () => widget.onPick(m.value),
      ),
    );
  }
}
