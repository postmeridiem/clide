/// Messages the user sent while a turn was running, docked above the composer
/// (T-587). They are held clide-side until the turn ends, so each can still be
/// edited or dismissed. Lives in the interaction zone (D-78) — the
/// conversation only shows a message once it is actually sent.
///
/// Editing holds the whole queue ([onEditStart] / [onEditEnd]): a message must
/// not go out half-edited because the turn happened to end mid-edit.
library;

import 'package:clide/builtin/claude/src/stream_json_session.dart' show QueuedMessage;
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class QueuedMessagesDock extends StatefulWidget {
  const QueuedMessagesDock({
    super.key,
    required this.messages,
    required this.onDismiss,
    required this.onEdit,
    required this.onEditStart,
    required this.onEditEnd,
  });

  final List<QueuedMessage> messages;
  final void Function(String id) onDismiss;

  /// Commit an edit. Empty text is the caller's to treat as a dismiss.
  final void Function(String id, String text) onEdit;

  /// An edit began — hold the queue.
  final VoidCallback onEditStart;

  /// The edit ended (saved, cancelled, or its message vanished) — release it.
  final VoidCallback onEditEnd;

  @override
  State<QueuedMessagesDock> createState() => _QueuedMessagesDockState();
}

class _QueuedMessagesDockState extends State<QueuedMessagesDock> {
  String? _editingId;
  final _controller = TextEditingController();
  final _focus = FocusNode(debugLabel: 'queued-message-edit');

  @override
  void didUpdateWidget(covariant QueuedMessagesDock old) {
    super.didUpdateWidget(old);
    // The message being edited went away underneath us (the session died and
    // cleared its queue) — drop the edit, and with it the hold.
    final id = _editingId;
    if (id != null && !widget.messages.any((m) => m.id == id)) {
      _editingId = null;
      widget.onEditEnd();
    }
  }

  @override
  void dispose() {
    // Never leave the queue held by an edit nobody can finish.
    if (_editingId != null) widget.onEditEnd();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit(QueuedMessage m) {
    if (_editingId == null) widget.onEditStart();
    setState(() {
      _editingId = m.id;
      _controller.value = TextEditingValue(
        text: m.text,
        selection: TextSelection.collapsed(offset: m.text.length),
      );
    });
    _focus.requestFocus();
  }

  void _endEdit({required bool save}) {
    final id = _editingId;
    if (id == null) return;
    if (save) widget.onEdit(id, _controller.text);
    setState(() => _editingId = null);
    widget.onEditEnd();
  }

  // Enter saves, Shift+Enter is a newline, Esc cancels — the composer's keys.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _endEdit(save: false);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
      _endEdit(save: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _t(String key, String placeholder) => ClideSettings.i18n.string(context, key, namespace: 'builtin.claude', placeholder: placeholder);

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) return const SizedBox.shrink(); // no chrome when empty
    final tokens = ClideSettings.theme.of(context).surface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.listItemBackground,
          border: Border.all(color: tokens.panelBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final m in widget.messages) _row(tokens, m)]),
      ),
    );
  }

  Widget _row(SurfaceTokens tokens, QueuedMessage m) {
    final editing = m.id == _editingId;
    return Padding(
      key: ValueKey('queued-${m.id}'),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: ClideText(
              editing ? _t('queue.editing', 'editing') : _t('queue.tag', 'queued'),
              fontSize: clideFontCaption,
              color: editing ? tokens.globalFocus : tokens.globalTextMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: editing
                ? _editor(tokens)
                : ClideText(m.text, fontSize: clideFontSmall, color: tokens.globalTextMuted, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          if (editing) ...[
            _button(tokens, 'check', _t('queue.save', 'Save queued message'), const Key('queued-save'), () => _endEdit(save: true)),
            _button(tokens, 'x', _t('queue.cancelEdit', 'Cancel edit'), const Key('queued-cancel'), () => _endEdit(save: false)),
          ] else ...[
            _button(tokens, 'pencil-simple', _t('queue.edit', 'Edit queued message'), Key('queued-edit-${m.id}'), () => _startEdit(m)),
            _button(tokens, 'x', _t('queue.dismiss', 'Dismiss queued message'), Key('queued-dismiss-${m.id}'), () {
              if (_editingId == m.id) _endEdit(save: false);
              widget.onDismiss(m.id);
            }),
          ],
        ],
      ),
    );
  }

  Widget _editor(SurfaceTokens tokens) => Focus(
    onKeyEvent: _onKey,
    child: ClideEditable(
      key: const Key('queued-editor'),
      controller: _controller,
      focusNode: _focus,
      style: TextStyle(fontSize: clideFontSmall, color: tokens.globalForeground, height: 1.3),
      cursorColor: tokens.globalFocus,
      backgroundCursorColor: tokens.globalTextMuted,
      maxLines: 6,
      minLines: 1,
    ),
  );

  Widget _button(SurfaceTokens tokens, String icon, String label, Key key, VoidCallback onTap) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: ClideTappable(
      key: key,
      cursor: SystemMouseCursors.click,
      tooltip: label,
      onTap: onTap,
      builder: (ctx, hovered, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: ClideIcon(PhosphorIcons.byName(icon), size: 13, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
      ),
    ),
  );
}
