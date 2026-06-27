import 'package:clide/builtin/claude/src/account_registry.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/claude_account_commands.dart' show accountActionChannel;
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Settings control for "Account for this workspace" (T-482, epic T-476). A
/// dropdown of the registered Claude accounts plus a Default option; picking one
/// binds (or unbinds) the current workspace and publishes on
/// [accountActionChannel] — the same channel the CLI `set`/`unset` verbs use, so
/// the session respawns onto the account (T-480) and the IDE lock re-syncs
/// (T-479). Registry writes flow through the shared [SettingsStore], whose
/// notifier this control listens to, so it stays live for both UI and CLI edits.
class ClaudeWorkspaceAccountControl extends StatefulWidget {
  const ClaudeWorkspaceAccountControl({super.key});

  @override
  State<ClaudeWorkspaceAccountControl> createState() => _ClaudeWorkspaceAccountControlState();
}

class _ClaudeWorkspaceAccountControlState extends State<ClaudeWorkspaceAccountControl> {
  final ClideOverlayController _overlay = ClideOverlayController();
  SettingsStore? _settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = ClideKernel.maybeOf(context)?.settings;
    if (identical(settings, _settings)) return;
    _settings?.removeListener(_onChange);
    _settings = settings;
    _settings?.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settings?.removeListener(_onChange);
    _overlay.dispose();
    super.dispose();
  }

  static const _defaultLabel = 'Default';

  Future<void> _bind(KernelServices services, String cwd, String? name) async {
    _overlay.close();
    final reg = AccountRegistry(services.settings);
    // The registry write sets the in-memory binding synchronously, then flushes
    // to disk; publish once the binding is live (before the flush completes) so
    // the respawn (T-480) + lock-sync (T-479) consumers see the new state. The
    // settings notifier rebuilds us once the write lands.
    if (name == null) {
      final previous = reg.boundName(cwd);
      final write = reg.unbindWorkspace(cwd);
      services.messages.publish('ui', accountActionChannel, {'action': 'unset', 'cwd': cwd, 'previous': previous});
      await write;
    } else {
      final write = reg.bindWorkspace(cwd, name);
      services.messages.publish('ui', accountActionChannel, {'action': 'set', 'name': name, 'cwd': cwd});
      await write;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final services = ClideKernel.maybeOf(context);
    final cwd = services?.settings.projectDir?.path;
    if (services == null || cwd == null) {
      return ClideText('Open a workspace to bind a Claude account.', fontSize: clideFontCaption, color: tokens.globalTextMuted);
    }

    final reg = AccountRegistry(services.settings);
    final accounts = reg.accounts;
    if (accounts.isEmpty) {
      return ClideText('No accounts yet — add one with `clide claude account add <name>`.', fontSize: clideFontCaption, color: tokens.globalTextMuted);
    }

    final boundName = reg.boundName(cwd);
    final selectedLabel = boundName ?? _defaultLabel;
    return ClideAnchoredOverlay(
      controller: _overlay,
      align: ClideAnchorAlign.start,
      overlayBuilder: (ctx, c) => ClideMenu(
        onClose: c.close,
        entries: [
          ClideMenuItem(
            label: _defaultLabel,
            active: boundName == null,
            semanticLabel: 'Account for this workspace: $_defaultLabel',
            onSelect: () => _bind(services, cwd, null),
          ),
          const ClideMenuSeparator(),
          for (final a in accounts)
            ClideMenuItem(
              label: a.name,
              active: a.name == boundName,
              semanticLabel: 'Account for this workspace: ${a.name}',
              onSelect: () => _bind(services, cwd, a.name),
            ),
        ],
      ),
      anchor: Semantics(
        button: true,
        label: 'Account for this workspace: $selectedLabel. Click to change.',
        excludeSemantics: true,
        onTap: _overlay.toggle,
        child: ClideTappable(
          cursor: SystemMouseCursors.click,
          onTap: _overlay.toggle,
          builder: (ctx, hovered, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              border: Border.all(color: hovered ? tokens.panelActiveBorder : tokens.dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClideText(selectedLabel, color: tokens.globalForeground),
                const SizedBox(width: 6),
                ClideIcon(PhosphorIcons.byName('caret-down'), size: 10, color: tokens.globalTextMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
