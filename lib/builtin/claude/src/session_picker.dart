/// Modal picker for `/resume` (T-156): lists the workspace's Claude sessions,
/// each labelled `first user line … last user line` with its last-modified
/// time, and returns the chosen session id. No-Material (D-7); shown via the
/// [DialogRouter].
library;

import 'package:clide/builtin/claude/src/session_index.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class SessionPickerDialog extends StatefulWidget {
  const SessionPickerDialog({super.key, required this.sessions, required this.onPick, required this.onCancel});

  final List<SessionSummary> sessions;
  final void Function(String id) onPick;
  final VoidCallback onCancel;

  @override
  State<SessionPickerDialog> createState() => _SessionPickerDialogState();
}

class _SessionPickerDialogState extends State<SessionPickerDialog> {
  int _selected = 0;

  void _move(int delta) {
    if (widget.sessions.isEmpty) return;
    setState(() {
      _selected = (_selected + delta) % widget.sessions.length;
      if (_selected < 0) _selected += widget.sessions.length;
    });
  }

  void _confirm() {
    if (widget.sessions.isEmpty) return;
    widget.onPick(widget.sessions[_selected].id);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onCancel();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _confirm();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ClideSettings.theme.of(context).surface;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          color: theme.panelBackground,
          border: Border.all(color: theme.globalBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: ClideText('Resume a Claude session', fontSize: clideFontBody, color: theme.globalForeground),
            ),
            if (widget.sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                child: ClideText('No sessions found for this workspace.', muted: true, fontSize: clideFontSmall),
              )
            else
              Flexible(
                child: ListView.builder(shrinkWrap: true, itemCount: widget.sessions.length, itemBuilder: (ctx, i) => _row(theme, i)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(SurfaceTokens theme, int i) {
    final s = widget.sessions[i];
    final selected = i == _selected;
    return GestureDetector(
      onTap: () => widget.onPick(s.id),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          color: selected ? theme.panelActiveBorder : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClideText(s.label, fontSize: clideFontSmall, color: theme.globalForeground, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              ClideText(relativeTime(s.modified), muted: true, fontSize: clideFontSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Short human label for [when] relative to now ("just now", "5m ago", …).
String relativeTime(DateTime when, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(when);
  if (d.inSeconds < 45) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  final w = when.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${w.year}-${two(w.month)}-${two(w.day)}';
}
