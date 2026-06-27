/// Modal that hosts `CLAUDE_CONFIG_DIR=<dir> claude login` in a terminal pane
/// (T-485, epic T-476). clide writes no auth code: the Claude CLI owns the OAuth
/// browser flow, and clide just provides the TTY + the per-account config dir,
/// so the resulting credentials land in `<dir>` rather than the global
/// `~/.claude` (D-64 — one CLI-initiated browser flow, on explicit action,
/// nothing in the background). No-Material (D-7); shown via the DialogRouter.
library;

import 'package:clide/builtin/terminal/src/terminal_pane.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ClaudeLoginDialog extends StatelessWidget {
  const ClaudeLoginDialog({super.key, required this.name, required this.dir, required this.onClose, this.cwd});

  /// Account display name (for the title).
  final String name;

  /// The account's `CLAUDE_CONFIG_DIR` — where `claude login` writes credentials.
  final String dir;

  /// Working directory for the spawned `claude login` (defaults to the
  /// workspace); irrelevant to auth, but keeps the pane oriented.
  final String? cwd;

  final VoidCallback onClose;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      onClose();
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
        width: 760,
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
              child: Row(
                children: [
                  Expanded(
                    child: ClideText('Sign in: $name', fontSize: clideFontBody, color: theme.globalForeground),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close',
                    excludeSemantics: true,
                    child: ClideTappable(
                      key: const Key('account-login-close'),
                      cursor: SystemMouseCursors.click,
                      onTap: onClose,
                      builder: (ctx, hovered, _) =>
                          ClideIcon(PhosphorIcons.byName('x'), size: 14, color: hovered ? theme.globalForeground : theme.globalTextMuted),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: ClideText('Running `claude login` against $dir — finish the browser sign-in, then close.', muted: true, fontSize: clideFontSmall),
            ),
            // Fixed height — TerminalPane needs a bounded box; the dialog itself
            // sizes to its content (mainAxisSize.min).
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: SizedBox(
                height: 380,
                child: TerminalPane(argv: const ['claude', 'login'], env: {'CLAUDE_CONFIG_DIR': dir}, cwdOverride: cwd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
