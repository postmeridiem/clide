/// The per-repo account roadblock shown right after a new project is created
/// (T-488, story T-486). Only a freshly-created project reaches here (the
/// welcome dialog announces it on projectCreatedChannel) — existing opens never
/// prompt. The new project is already the open workspace, so the embedded
/// per-workspace picker binds it directly; the accounts list lets a first-run
/// user add + sign in to an account before picking. No-Material (D-7).
library;

import 'package:clide/builtin/claude/src/account_settings_control.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ClaudeAccountRoadblockDialog extends StatelessWidget {
  const ClaudeAccountRoadblockDialog({super.key, required this.projectName, required this.onClose});

  final String projectName;
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
        width: 560,
        constraints: const BoxConstraints(maxHeight: 540),
        decoration: BoxDecoration(
          color: theme.modalSurfaceBackground,
          border: Border.all(color: theme.modalSurfaceBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClideText('Claude account for $projectName', fontSize: clideFontDialogTitle, fontWeight: FontWeight.w600, color: theme.globalForeground),
                const SizedBox(height: 4),
                ClideText(
                  'Pick which Claude account this new project runs under, or keep the default system login. You can change it later in Settings or the pane badge.',
                  muted: true,
                  fontSize: clideFontMeta,
                ),
                const SizedBox(height: 18),
                ClideText('Account for this project', fontSize: clideFontMeta, muted: true),
                const SizedBox(height: 6),
                const Align(alignment: Alignment.centerLeft, child: ClaudeWorkspaceAccountControl()),
                const SizedBox(height: 18),
                ClideText('Accounts', fontSize: clideFontMeta, muted: true),
                const SizedBox(height: 6),
                const ClaudeAccountsListControl(),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: ClideButton(label: 'Continue', onPressed: onClose),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
