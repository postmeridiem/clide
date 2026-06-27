import 'dart:io' show Platform;

import 'package:clide/builtin/claude/src/account_registry.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/claude_account_commands.dart' show accountActionChannel;
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Bind (or, with [name] null, unbind) [cwd] to a Claude account and publish on
/// [accountActionChannel] so the session respawns (T-480) and the IDE lock
/// re-syncs (T-479). The registry write sets the in-memory binding
/// synchronously then flushes; publishing before the flush keeps the bus
/// consumers in step. Shared by the settings picker and the pane badge (T-481).
Future<void> bindWorkspaceAccount(KernelServices services, String cwd, String? name) async {
  final reg = AccountRegistry(services.settings);
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

/// A stable, token-derived accent for an account [name] so each window's badge
/// reads at a glance (T-481). Hash-indexed into a fixed set of theme tokens —
/// never an arbitrary colour (the palette stays theme-owned). Null name (the
/// default account) returns the muted token.
Color accountAccent(String? name, SurfaceTokens tokens) {
  if (name == null || name.isEmpty) return tokens.globalTextMuted;
  final accents = [tokens.globalFocus, tokens.statusSuccess, tokens.statusWarning, tokens.statusError, tokens.buttonBackground];
  var h = 0;
  for (final unit in name.codeUnits) {
    h = (h * 31 + unit) & 0x7fffffff;
  }
  return accents[h % accents.length];
}

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
    await bindWorkspaceAccount(services, cwd, name);
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

/// Settings control for the global Claude accounts registry (T-482, epic
/// T-476). Lists each registered account — sign-in status dot, name, config
/// dir — with re-login and remove affordances, plus an inline "add account"
/// field. Management flows through the AccountRegistry + accountActionChannel
/// (the CLI verbs' path); removal is refused while a workspace is bound, to
/// match `clide claude account remove`.
class ClaudeAccountsListControl extends StatefulWidget {
  const ClaudeAccountsListControl({super.key});

  @override
  State<ClaudeAccountsListControl> createState() => _ClaudeAccountsListControlState();
}

class _ClaudeAccountsListControlState extends State<ClaudeAccountsListControl> {
  final TextEditingController _name = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'add-account');
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
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add(KernelServices services) async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final reg = AccountRegistry(services.settings);
    if (reg.accountByName(name) != null) {
      _name.clear();
      return; // idempotent — already registered
    }
    final dir = '${Platform.environment['HOME'] ?? ''}/.claude-$name';
    _name.clear();
    final write = reg.registerAccount(name, dir);
    // Kick off the login flow for the new account (T-485 consumer opens it).
    services.messages.publish('ui', accountActionChannel, {'action': 'login', 'name': name, 'dir': dir});
    await write;
  }

  void _relogin(KernelServices services, Account a) {
    services.messages.publish('ui', accountActionChannel, {'action': 'login', 'name': a.name, 'dir': a.dir});
  }

  Future<void> _remove(KernelServices services, String name) => AccountRegistry(services.settings).removeAccount(name);

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final services = ClideKernel.maybeOf(context);
    if (services == null) return const SizedBox.shrink();
    final reg = AccountRegistry(services.settings);
    final accounts = reg.accounts;
    final bound = reg.boundAccountNames();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (accounts.isEmpty)
          ClideText('No accounts registered yet.', fontSize: clideFontCaption, color: tokens.globalTextMuted)
        else
          for (final a in accounts) _row(context, services, tokens, a, bound.contains(a.name)),
        const SizedBox(height: 10),
        _addRow(context, services, tokens),
      ],
    );
  }

  Widget _row(BuildContext context, KernelServices services, SurfaceTokens tokens, Account a, bool isBound) {
    final signedIn = accountIsSignedIn(a.dir);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: signedIn ? tokens.statusSuccess : tokens.globalTextMuted),
          ),
          const SizedBox(width: 8),
          ClideText(a.name, color: tokens.globalForeground),
          const SizedBox(width: 10),
          Expanded(
            child: ClideText(a.dir, fontSize: clideFontCaption, muted: true, fontFamily: ClideSettings.fonts.monoOf(context), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          _iconButton(context, 'sign-in', signedIn ? 'Re-sign in to ${a.name}' : 'Sign in to ${a.name}', () => _relogin(services, a)),
          const SizedBox(width: 6),
          _iconButton(
            context,
            'trash',
            isBound ? '${a.name} is bound to a workspace — unset it first' : 'Remove ${a.name}',
            isBound ? null : () => _remove(services, a.name),
            color: isBound ? tokens.globalTextMuted : tokens.statusError,
          ),
        ],
      ),
    );
  }

  Widget _iconButton(BuildContext context, String icon, String semantic, VoidCallback? onTap, {Color? color}) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semantic,
      excludeSemantics: true,
      child: ClideTappable(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onTap: onTap,
        builder: (ctx, hovered, _) =>
            ClideIcon(PhosphorIcons.byName(icon), size: 14, color: color ?? (hovered ? tokens.globalForeground : tokens.globalTextMuted)),
      ),
    );
  }

  Widget _addRow(BuildContext context, KernelServices services, SurfaceTokens tokens) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 26,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              border: Border.all(color: _focus.hasFocus ? tokens.panelActiveBorder : tokens.dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: EditableText(
              controller: _name,
              focusNode: _focus,
              style: TextStyle(fontFamily: ClideSettings.fonts.monoOf(context), fontSize: clideFontMono, color: tokens.globalForeground),
              cursorColor: tokens.globalFocus,
              backgroundCursorColor: tokens.globalTextMuted,
              maxLines: 1,
              onSubmitted: (_) => _add(services),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Add account',
          excludeSemantics: true,
          child: ClideTappable(
            cursor: SystemMouseCursors.click,
            onTap: () => _add(services),
            builder: (ctx, hovered, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: hovered ? tokens.listItemHoverBackground : tokens.buttonBackground, borderRadius: BorderRadius.circular(4)),
              child: ClideText('Add account', color: tokens.buttonForeground, fontSize: clideFontCaption),
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact account badge for the Claude pane chrome (T-481, epic T-476). Shows
/// the workspace's bound account (or "default"), tinted by [accountAccent] so
/// each window is distinguishable at a glance. Tapping opens a picker of the
/// registered accounts + Default. Hidden when no accounts are registered (the
/// feature is unused). Live via the settings notifier.
class ClaudeAccountBadge extends StatefulWidget {
  const ClaudeAccountBadge({super.key, required this.workspaceRoot});

  final String? workspaceRoot;

  @override
  State<ClaudeAccountBadge> createState() => _ClaudeAccountBadgeState();
}

class _ClaudeAccountBadgeState extends State<ClaudeAccountBadge> {
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

  Future<void> _pick(KernelServices services, String? name) async {
    _overlay.close();
    final cwd = widget.workspaceRoot;
    if (cwd != null) await bindWorkspaceAccount(services, cwd, name);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final services = ClideKernel.maybeOf(context);
    final cwd = widget.workspaceRoot;
    if (services == null || cwd == null) return const SizedBox.shrink();
    final reg = AccountRegistry(services.settings);
    final accounts = reg.accounts;
    if (accounts.isEmpty) return const SizedBox.shrink(); // feature unused — no chrome noise
    final boundName = reg.boundName(cwd);
    final label = boundName ?? 'default';
    final accent = accountAccent(boundName, tokens);
    return ClideAnchoredOverlay(
      controller: _overlay,
      align: ClideAnchorAlign.end,
      overlayBuilder: (ctx, c) => ClideMenu(
        onClose: c.close,
        entries: [
          ClideMenuItem(label: 'default', active: boundName == null, semanticLabel: 'Account: default', onSelect: () => _pick(services, null)),
          const ClideMenuSeparator(),
          for (final a in accounts)
            ClideMenuItem(label: a.name, active: a.name == boundName, semanticLabel: 'Account: ${a.name}', onSelect: () => _pick(services, a.name)),
        ],
      ),
      anchor: Semantics(
        button: true,
        label: 'Claude account: $label. Click to change.',
        excludeSemantics: true,
        onTap: _overlay.toggle,
        child: ClideTappable(
          cursor: SystemMouseCursors.click,
          onTap: _overlay.toggle,
          builder: (ctx, hovered, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: hovered ? tokens.listItemHoverBackground : null,
              border: Border.all(color: accent),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                ),
                const SizedBox(width: 5),
                ClideText(label, fontSize: clideFontCaption, color: boundName == null ? tokens.globalTextMuted : tokens.globalForeground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
