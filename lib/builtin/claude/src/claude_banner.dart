/// Native startup banner for the empty Claude pane (T-149).
///
/// Shown by [ConversationView] before any transcript items arrive — a
/// clide-branded placeholder (clide's own logo) that orients the user:
/// which session, which workspace, what status. The "Claude" label uses
/// Anthropic's published accent colour ([claudeAccent], #d97757) purely
/// to identify Claude — nominative use; clide bundles no Anthropic
/// artwork (see assets/licenses.yaml trademark_notices).
library;

import 'dart:io' show Platform;

import 'package:clide/builtin/claude/src/conversation_view.dart' show claudeAccent;
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ClaudeBanner extends StatelessWidget {
  const ClaudeBanner({super.key, required this.role, this.workspace, this.statusLine});

  /// Session role, e.g. `'primary'` or `'secondary 2'`.
  final String role;

  /// Repo root for this session (shown home-collapsed).
  final String? workspace;

  /// Status line, e.g. `'tmux · clide-claude-…'`.
  final String? statusLine;

  @override
  Widget build(BuildContext context) {
    final ws = _collapseHome(workspace);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ClideSvgView.asset('assets/logo/logo.svg', width: 60, height: 60),
          const SizedBox(height: 18),
          ClideText(
            'Claude',
            fontSize: clideFontDialogTitle,
            color: claudeAccent,
            fontWeight: FontWeight.w500,
          ),
          const SizedBox(height: 2),
          ClideText(role, fontSize: clideFontSmall, muted: true, fontFamily: clideMonoFamily),
          const SizedBox(height: 16),
          if (ws != null) ClideText(ws, fontSize: clideFontCaption, muted: true),
          if (statusLine != null) ...[
            const SizedBox(height: 2),
            ClideText(statusLine!, fontSize: clideFontSmall, muted: true, fontFamily: clideMonoFamily),
          ],
          const SizedBox(height: 16),
          const ClideText('Warming up — your conversation will appear here.', fontSize: clideFontSmall, muted: true),
        ],
      ),
    );
  }

  static String? _collapseHome(String? path) {
    if (path == null) return null;
    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty && path.startsWith(home)) return '~${path.substring(home.length)}';
    return path;
  }
}
