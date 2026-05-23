/// Modal showing the workspace's Claude session transcripts with their
/// on-disk sizes and a user-driven cleanup (T-148). Per-row delete is a
/// deliberate two-click confirm; clide never deletes transcripts on its own.
/// No-Material (D-7); shown via the [DialogRouter].
library;

import 'dart:io';

import 'package:clide/builtin/claude/src/session_index.dart';
import 'package:clide/builtin/claude/src/session_picker.dart' show relativeTime;
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef SessionDeleter = Future<void> Function(Directory dir, String id);

class SessionStorageDialog extends StatefulWidget {
  const SessionStorageDialog({
    super.key,
    required this.dir,
    required this.sessions,
    required this.onClose,
    this.deleter = deleteSession,
  });

  final Directory dir;
  final List<SessionSummary> sessions;
  final VoidCallback onClose;

  /// Injected so tests don't touch the real filesystem.
  final SessionDeleter deleter;

  @override
  State<SessionStorageDialog> createState() => _SessionStorageDialogState();
}

class _SessionStorageDialogState extends State<SessionStorageDialog> {
  late final List<SessionSummary> _sessions = List.of(widget.sessions);
  String? _confirmingId;

  int get _total => _sessions.fold(0, (a, s) => a + s.sizeBytes);

  Future<void> _delete(SessionSummary s) async {
    await widget.deleter(widget.dir, s.id);
    if (!mounted) return;
    setState(() {
      _sessions.remove(s);
      _confirmingId = null;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ClideTheme.of(context).surface;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 460),
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
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: ClideText(
                'Session storage  ·  ${formatBytes(_total)} total',
                fontSize: clideFontBody,
                color: theme.globalForeground,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: ClideText(
                'Deleting a session you are currently using will break that pane.',
                muted: true,
                fontSize: clideFontSmall,
              ),
            ),
            if (_sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                child: ClideText('No sessions found for this workspace.', muted: true, fontSize: clideFontSmall),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sessions.length,
                  itemBuilder: (ctx, i) => _row(theme, _sessions[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(SurfaceTokens theme, SessionSummary s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClideText(s.label, fontSize: clideFontSmall, color: theme.globalForeground, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                ClideText('${relativeTime(s.modified)}  ·  ${formatBytes(s.sizeBytes)}', muted: true, fontSize: clideFontSmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _deleteControl(theme, s),
        ],
      ),
    );
  }

  Widget _deleteControl(SurfaceTokens theme, SessionSummary s) {
    if (_confirmingId == s.id) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _action('Delete', theme.globalForeground, () => _delete(s)),
          const SizedBox(width: 8),
          _action('Keep', theme.globalTextMuted, () => setState(() => _confirmingId = null)),
        ],
      );
    }
    return _action('Delete', theme.globalTextMuted, () => setState(() => _confirmingId = s.id));
  }

  Widget _action(String label, Color color, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ClideText(label, fontSize: clideFontSmall, color: color),
        ),
      ),
    );
  }
}
