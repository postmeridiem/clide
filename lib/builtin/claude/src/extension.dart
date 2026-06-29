import 'dart:async';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/builtin/claude/src/account_registry.dart';
import 'package:clide/builtin/claude/src/account_login_dialog.dart';
import 'package:clide/builtin/claude/src/account_roadblock_dialog.dart';
import 'package:clide/builtin/claude/src/account_settings_control.dart';
import 'package:clide/builtin/claude/src/activity_cluster.dart' show foldLevelFromName, kActivityFoldLevelKey, nextFoldLevel;
import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/claude_status.dart' show nextSafePermissionMode;
import 'package:clide/builtin/claude/src/conversation_view.dart' show claudeAccent;
import 'package:clide/builtin/claude/src/claude_session_host.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/pane_context_status.dart';
import 'package:clide/builtin/claude/src/claude_meta_sidebar.dart';
import 'package:clide/builtin/claude/src/session_defaults.dart';
import 'package:clide/builtin/claude/src/session_index.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart' show kEffortLevels, kFallbackModels, kPermissionModes;
import 'package:clide/builtin/claude/src/session_storage.dart';
import 'package:clide/builtin/claude/src/ticket_pick_up.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart' show DrawingMessage, IconEntry, IconMessage, ImageMessage;
import 'package:clide/src/daemon/claude_account_commands.dart' show accountActionChannel;
import 'package:clide/src/daemon/project_commands.dart' show projectCreatedChannel;
import 'package:clide/src/daemon/draw_commands.dart' show drawShowChannel;
import 'package:clide/src/daemon/icon_commands.dart' show iconShowChannel;
import 'package:clide/src/daemon/image_commands.dart' show imageShowChannel;
import 'package:clide/builtin/claude/src/team_chat_sidebar.dart' show TeamChatPane;
import 'package:clide/builtin/claude/src/team_panel_host.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// D-6 contract (T-391): a failed command returns an ERROR envelope (non-zero
/// CLI exit), never `ok` with an `error` field a script can't detect.
IpcResponse _userErr(String msg, {String? hint}) => IpcResponse.err(
  id: '',
  error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: msg, hint: hint),
);

IpcResponse _notFound(String msg) => IpcResponse.err(
  id: '',
  error: IpcError(code: IpcExitCode.notFound, kind: IpcErrorKind.notFound, message: msg),
);

class ClaudeExtension extends ClideExtension {
  @override
  String get id => 'builtin.claude';
  @override
  String get title => 'Claude';
  @override
  String get version => '0.2.0';
  @override
  // No runtime dependency on builtin.terminal: the login pane (T-485) reuses the
  // TerminalPane *widget* (a code import), which spawns via the always-present
  // pane.spawn IPC — it doesn't need the terminal extension activated.
  List<String> get dependsOn => const [];

  ClideExtensionContext? _ctx;
  final GlobalKey<ClaudeSessionHostState> _hostKey = GlobalKey();

  ClaudeConfig? _config;
  ClaudeSessionOrchestrator? _orchestrator;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Active workspace root, tracked so an in-place project switch can tear
  /// down the previous repo's sessions (T-269).
  String? _projectRoot;

  /// App-wide Claude environment (skills, commands, settings, permissions,
  /// slash list). Built and loaded at activation (D-76, T-151).
  ClaudeConfig? get config => _config;

  @override
  List<ContributionPoint> get contributions => [
    TabContribution(
      id: 'claude.primary',
      slot: Slots.workspace,
      title: 'Claude',
      titleKey: 'tab.title',
      i18nNamespace: id,
      priority: 90,
      build: (_) => TeamPanelHost(lead: ClaudeSessionHost(key: _hostKey)),
    ),
    CommandContribution(
      id: 'claude.new-secondary',
      command: 'claude.new-secondary',
      title: 'Claude: open a secondary session',
      titleKey: 'command.newSecondary',
      i18nNamespace: id,
      run: (_) async {
        _hostKey.currentState?.addSecondary();
        return IpcResponse.ok(id: '', data: const {'status': 'spawned'});
      },
    ),
    CommandContribution(
      id: 'claude.kill-all-sessions',
      command: 'claude.kill-all-sessions',
      title: 'Claude: kill all sessions for this repo',
      titleKey: 'command.killAllSessions',
      i18nNamespace: id,
      run: _killAllSessions,
    ),
    CommandContribution(
      id: 'claude.session-storage',
      command: 'claude.session-storage',
      title: 'Claude: session storage (disk usage + cleanup)',
      titleKey: 'command.sessionStorage',
      i18nNamespace: id,
      run: _manageStorage,
    ),
    // T-235: cycle how aggressively the activity card folds meta steps
    // (none → tools → thinking → everything), persisted app-wide. The panes
    // read kActivityFoldLevelKey and rebuild via the settings notifier.
    CommandContribution(
      id: 'claude.activity.fold-level',
      command: 'claude.activity.fold-level',
      title: 'Claude: cycle activity fold level',
      titleKey: 'command.activity.foldLevel',
      i18nNamespace: id,
      run: _cycleFoldLevel,
    ),
    // Activity settings category (T-453) — the fold level as a schema field,
    // written to kActivityFoldLevelKey; the panes already rebuild off the
    // settings notifier, so picking a level applies live.
    SettingsCategoryContribution(
      id: 'activity',
      category: SettingsCategory(
        id: 'activity',
        title: 'Activity',
        titleKey: 'settings.activity.title',
        i18nNamespace: id,
        iconName: 'cards-three',
        priority: 50,
        sections: [
          SettingsSection(
            label: 'Conversation',
            labelKey: 'settings.activity.conversation.label',
            fields: [
              SettingsField(
                key: kActivityFoldLevelKey,
                kind: SettingsFieldKind.select,
                label: 'Fold level',
                labelKey: 'settings.activity.foldLevel.label',
                help: 'How aggressively the conversation folds tool calls, thinking, and results.',
                helpKey: 'settings.activity.foldLevel.help',
                defaultValue: 'tools',
                options: [
                  SettingsOption(value: 'none', label: 'Show everything', labelKey: 'settings.activity.opt.none'),
                  SettingsOption(value: 'tools', label: 'Fold tool calls', labelKey: 'settings.activity.opt.tools'),
                  SettingsOption(value: 'thinking', label: 'Fold tools + thinking', labelKey: 'settings.activity.opt.thinking'),
                  SettingsOption(value: 'everything', label: 'Fold all but prose', labelKey: 'settings.activity.opt.everything'),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
    // Claude settings category (T-457) — defaults applied to NEW sessions
    // (the pane reads these keys at spawn). Effort flows through --effort;
    // model + permission mode are sent as control requests post-spawn.
    SettingsCategoryContribution(
      id: 'claude',
      category: SettingsCategory(
        id: 'claude',
        title: 'Claude',
        titleKey: 'settings.claude.title',
        i18nNamespace: id,
        iconName: 'sparkle',
        priority: 40,
        sections: [
          SettingsSection(
            label: 'New session defaults',
            labelKey: 'settings.claude.newSessionDefaults.label',
            fields: [
              SettingsField(
                key: kDefaultModelKey,
                kind: SettingsFieldKind.select,
                label: 'Model',
                labelKey: 'settings.claude.model.label',
                help: 'Model for new sessions.',
                helpKey: 'settings.claude.model.help',
                defaultValue: 'default',
                options: [for (final m in kFallbackModels) SettingsOption(value: m.value, label: m.displayName)],
              ),
              SettingsField(
                key: kDefaultEffortKey,
                kind: SettingsFieldKind.select,
                label: 'Effort',
                labelKey: 'settings.claude.effort.label',
                help: 'Reasoning effort for new sessions (applied via --effort at spawn).',
                helpKey: 'settings.claude.effort.help',
                defaultValue: 'high',
                options: [for (final l in kEffortLevels) SettingsOption(value: l.value, label: l.displayName)],
              ),
              SettingsField(
                key: kDefaultPermissionModeKey,
                kind: SettingsFieldKind.select,
                label: 'Permission mode',
                labelKey: 'settings.claude.permissionMode.label',
                help: 'Starting permission mode for new sessions.',
                helpKey: 'settings.claude.permissionMode.help',
                defaultValue: 'default',
                options: [for (final p in kPermissionModes) SettingsOption(value: p.value, label: p.displayName)],
              ),
            ],
          ),
          // Per-repo Claude account (T-482, epic T-476). The dropdown binds this
          // workspace to a registered account; manage the registry itself with
          // the `clide claude account` verbs (T-480).
          SettingsSection(
            label: 'Account',
            labelKey: 'settings.claude.account.label',
            fields: [
              SettingsField(
                // Placeholder keys — custom fields are rendered by their control,
                // never stored here; kept clear of the app.claude.account.<hash>
                // binding namespace the registry scans (T-480).
                key: 'app.claude.accountsRegistry',
                kind: SettingsFieldKind.custom,
                label: 'Accounts',
                labelKey: 'settings.claude.account.registry.label',
                help: 'Registered Claude accounts (each a separate config dir + login).',
                helpKey: 'settings.claude.account.registry.help',
                customId: 'claude.accounts',
              ),
              SettingsField(
                key: 'app.claude.workspaceAccount',
                kind: SettingsFieldKind.custom,
                label: 'Account for this workspace',
                labelKey: 'settings.claude.account.workspace.label',
                help: 'Which Claude account this repo runs under; Default uses the system login.',
                helpKey: 'settings.claude.account.workspace.help',
                customId: 'claude.workspace-account',
              ),
            ],
          ),
        ],
      ),
    ),
    SettingsControlContribution(id: 'claude.accounts', customId: 'claude.accounts', builder: (_) => const ClaudeAccountsListControl()),
    SettingsControlContribution(id: 'claude.workspace-account', customId: 'claude.workspace-account', builder: (_) => const ClaudeWorkspaceAccountControl()),
    // T-171: agent roster controls (D-6 CLI/UI parity).
    // Usage: clide claude.agent.show <sessionId>
    CommandContribution(
      id: 'claude.agent.show',
      command: 'claude.agent.show',
      title: 'Claude: show an agent session pane',
      titleKey: 'command.agent.show',
      i18nNamespace: id,
      run: (args) async {
        final id = args.firstOrNull;
        if (id == null) return _userErr('missing session id');
        _orchestrator?.show(id);
        return IpcResponse.ok(id: '', data: {'id': id, 'status': 'shown'});
      },
    ),
    CommandContribution(
      id: 'claude.agent.hide',
      command: 'claude.agent.hide',
      title: 'Claude: hide an agent session pane',
      titleKey: 'command.agent.hide',
      i18nNamespace: id,
      run: (args) async {
        final id = args.firstOrNull;
        if (id == null) return _userErr('missing session id');
        _orchestrator?.hide(id);
        return IpcResponse.ok(id: '', data: {'id': id, 'status': 'hidden'});
      },
    ),
    CommandContribution(
      id: 'claude.agent.close',
      command: 'claude.agent.close',
      title: 'Claude: close (kill) an agent session',
      titleKey: 'command.agent.close',
      i18nNamespace: id,
      run: (args) async {
        final id = args.firstOrNull;
        if (id == null) return _userErr('missing session id');
        await _orchestrator?.close(id);
        return IpcResponse.ok(id: '', data: {'id': id, 'status': 'closed'});
      },
    ),
    CommandContribution(
      id: 'claude.agent.mute',
      command: 'claude.agent.mute',
      title: 'Claude: mute broker delivery to an agent session',
      titleKey: 'command.agent.mute',
      i18nNamespace: id,
      run: (args) async {
        final id = args.firstOrNull;
        if (id == null) return _userErr('missing session id');
        _orchestrator?.mute(id);
        return IpcResponse.ok(id: '', data: {'id': id, 'status': 'muted'});
      },
    ),
    CommandContribution(
      id: 'claude.agent.unmute',
      command: 'claude.agent.unmute',
      title: 'Claude: unmute broker delivery to an agent session',
      titleKey: 'command.agent.unmute',
      i18nNamespace: id,
      run: (args) async {
        final id = args.firstOrNull;
        if (id == null) return _userErr('missing session id');
        _orchestrator?.unmute(id);
        return IpcResponse.ok(id: '', data: {'id': id, 'status': 'unmuted'});
      },
    ),
    // Usage: clide claude.agent.inject-message <sessionId> <text...>
    CommandContribution(
      id: 'claude.agent.inject-message',
      command: 'claude.agent.inject-message',
      title: 'Claude: inject a text turn into an agent session',
      titleKey: 'command.agent.injectMessage',
      i18nNamespace: id,
      run: (args) async {
        final id = args.firstOrNull;
        if (id == null) return _userErr('missing session id');
        final text = args.skip(1).join(' ');
        if (text.isEmpty) return _userErr('missing message text');
        _orchestrator?.injectMessage(id, text);
        return IpcResponse.ok(id: '', data: {'id': id, 'status': 'injected'});
      },
    ),
    // T-181: set permission mode for an agent session (D-6 CLI/UI parity).
    // Usage: clide claude.agent.set-permission-mode <sessionId> <mode>
    // <mode> must be one of: default, acceptEdits, plan, bypassPermissions.
    // Note: bypassPermissions is accepted via CLI — the footgun guard is the
    // UI's confirm dialog; the CLI caller is responsible for their own safety.
    CommandContribution(
      id: 'claude.agent.set-permission-mode',
      command: 'claude.agent.set-permission-mode',
      title: 'Claude: set permission mode for an agent session',
      titleKey: 'command.agent.setPermissionMode',
      i18nNamespace: id,
      run: (args) async {
        final id = args.firstOrNull;
        if (id == null) return _userErr('missing session id');
        final mode = args.length >= 2 ? args[1] : null;
        if (mode == null) return _userErr('missing mode (default|acceptEdits|plan|bypassPermissions)');
        const valid = {'default', 'acceptEdits', 'plan', 'bypassPermissions'};
        if (!valid.contains(mode)) {
          return _userErr('unknown mode "$mode"; use one of: ${valid.join(', ')}');
        }
        _orchestrator?.byId(id)?.session.setPermissionMode(mode);
        return IpcResponse.ok(id: '', data: {'id': id, 'mode': mode, 'status': 'sent'});
      },
    ),
    // T-226: cycle the primary session's permission mode through the safe
    // trio. Palette-discoverable counterpart to the composer's Ctrl/Cmd+M.
    CommandContribution(
      id: 'claude.mode.cycle',
      command: 'claude.mode.cycle',
      title: 'Claude: Cycle permission mode',
      titleKey: 'command.mode.cycle',
      i18nNamespace: id,
      run: (_) async {
        final managed = _orchestrator?.byId('primary');
        if (managed == null) return _notFound('no primary session');
        final next = nextSafePermissionMode(managed.session.status.permissionMode ?? 'default');
        managed.session.setPermissionMode(next);
        return IpcResponse.ok(id: '', data: {'mode': next, 'status': 'sent'});
      },
    ),
    // Usage: clide claude.task.reassign <taskId> <toSessionId>
    CommandContribution(
      id: 'claude.task.reassign',
      command: 'claude.task.reassign',
      title: 'Claude: reassign a shared task to an agent',
      titleKey: 'command.task.reassign',
      i18nNamespace: id,
      run: (args) async {
        if (args.length < 2) return _userErr('usage: <taskId> <sessionId>');
        final taskId = args[0];
        final toId = args[1];
        final ok = _orchestrator?.broker.reassignTask(taskId, toId) ?? false;
        if (!ok) return _notFound('could not reassign task "$taskId" to "$toId"');
        return IpcResponse.ok(id: '', data: {'taskId': taskId, 'toId': toId, 'ok': true});
      },
    ),
    // T-180: full team chat pane opened as a workspace tab.
    // Shares the TeamChatModel with the sidebar widget.
    TabContribution(
      id: 'claude.team-chat',
      slot: Slots.workspace,
      title: 'Team Chat',
      titleKey: 'tab.title',
      i18nNamespace: id,
      priority: 85,
      build: (_) {
        final orch = _orchestrator;
        if (orch == null) return const SizedBox.shrink();
        return TeamChatPane(model: orch.chatModel, broker: orch.broker);
      },
    ),
    // CLI parity: open the team chat pane from the shell.
    // Usage: clide claude.team-chat.open
    CommandContribution(
      id: 'claude.team-chat.open',
      command: 'claude.team-chat.open',
      title: 'Claude: open the team chat pane',
      titleKey: 'command.teamChat.open',
      i18nNamespace: id,
      run: (args) async {
        _ctx?.panels.activateTab(Slots.workspace, 'claude.team-chat');
        return IpcResponse.ok(id: '', data: const {'status': 'opened'});
      },
    ),
    // Usage: clide claude.team-chat.post [@name] <text...>
    // Posts a message into the broker channel as the user.
    // Leading @name tag selects the recipient; omit for broadcast.
    CommandContribution(
      id: 'claude.team-chat.post',
      command: 'claude.team-chat.post',
      title: 'Claude: post a message into the team channel as the user',
      titleKey: 'command.teamChat.post',
      i18nNamespace: id,
      run: (args) async {
        if (args.isEmpty) return _userErr('usage: [@name] <text>');
        final raw = args.join(' ');
        String? recipient;
        String body = raw;
        if (raw.startsWith('@')) {
          final ws = raw.indexOf(RegExp(r'\s'));
          if (ws > 0) {
            final tag = raw.substring(1, ws);
            recipient = (tag == 'team' || tag.isEmpty) ? null : tag;
            body = raw.substring(ws).trim();
          }
        }
        _orchestrator?.chatModel.postAsUser(body, toName: recipient);
        return IpcResponse.ok(id: '', data: {'status': 'posted', 'to': ?recipient});
      },
    ),
    // claude.agent.fork: branch a managed session into a new fork session
    // (T-172, D-6 CLI/UI parity for the roster fork button).
    // Usage: clide claude.agent.fork <sourceSessionId> [<cwd>]
    // <sourceSessionId>: the clide-internal id of the session to fork.
    // <cwd>: optional working directory; defaults to the source session's cwd.
    CommandContribution(
      id: 'claude.agent.fork',
      command: 'claude.agent.fork',
      title: 'Claude: fork a managed session into a new branch session',
      titleKey: 'command.agent.fork',
      i18nNamespace: id,
      run: (args) async {
        final sourceId = args.firstOrNull;
        if (sourceId == null) {
          return _userErr('usage: claude.agent.fork <sourceSessionId> [<cwd>]');
        }
        final orch = _orchestrator;
        if (orch == null) {
          return IpcResponse.err(
            id: '',
            error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'orchestrator unavailable'),
          );
        }
        final source = orch.byId(sourceId);
        if (source == null) {
          return _notFound('unknown session "$sourceId"');
        }
        final cwd = args.length >= 2 ? args[1] : source.cwd;
        final forkId = 'fork:$sourceId-${DateTime.now().millisecondsSinceEpoch}';
        await orch.spawn(SpawnSpec(id: forkId, role: 'fork of $sourceId', sessionId: forkId, cwd: cwd, forkSourceSessionId: source.sessionId));
        return IpcResponse.ok(id: '', data: {'forkId': forkId, 'sourceId': sourceId, 'status': 'spawned'});
      },
    ),
    // Always-pickable left-panel tab: Claude activity (from
    // stats-cache.json) + the team roster when a team is running (T-141).
    TabContribution(
      id: 'claude.meta',
      slot: Slots.sidebar,
      title: 'Activity',
      icon: PhosphorIcons.byName('robot'),
      // Claude's accent marks Claude's own panel in the rail (T-418) —
      // nominative use per the licenses.yaml trademark note.
      iconColor: claudeAccent,
      priority: 60,
      build: (_) => const ClaudeMetaSidebar(),
    ),
    // In-pane status slot (T-145): the active Claude pane publishes
    // its model · permission-mode · context line here.
    // flex: 1 → StatusbarHost wraps this in Flexible(loose) so the slot
    // yields width under pressure and ClideMarquee scrolls (T-160).
    StatusItemContribution(id: 'claude.status-context', priority: 50, flex: 1, build: (_) => const PaneContextStatusItem()),
  ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;

    // Resolve the Claude environment up front (app-init): version + the
    // version-keyed slash probe + the layered global/local config. Exposed
    // as the builtin-owned singleton so panes + the status item read one
    // source of truth (D-76, T-151). Reloaded as the workspace changes.
    final home = Platform.environment['HOME'];
    if (home != null) {
      final cfg = ClaudeConfig(
        globalDir: Directory('$home/.claude'),
        cacheDir: Directory('${ctx.settings.appDir.path}/claude'),
        projectDir: ctx.settings.projectDir,
      );
      _config = cfg;
      activeClaudeConfig = cfg;
      unawaited(cfg.load());
      _subs.add(ctx.events.on<ProjectOpened>().listen((e) => cfg.setProjectDir(Directory(e.path))));
    }

    // The clide-managed session set (T-169). Panes spawn/bind through it so a
    // session outlives its pane and is shared across surfaces. The account
    // registry (T-476) lets a bound workspace spawn under its own Claude account.
    _orchestrator = ClaudeSessionOrchestrator(accountRegistry: AccountRegistry(ctx.settings));
    activeSessionOrchestrator = _orchestrator;

    // An in-place workspace switch (Open Project/Folder) must not leave the
    // previous repo's sessions running — including team/non-pane sessions the
    // panes don't own. Close every session that doesn't belong to the new
    // root; panes rebind themselves to the new repo (T-269).
    _subs.add(ctx.events.on<ProjectOpened>().listen(_onProjectChanged));

    // `clide image show <path>` (T-249): the dispatcher resolves + publishes an
    // 'image' message; we inject the matching card into the conversation the
    // user is looking at (the primary lead, else the first visible session).
    _subs.add(ctx.messages.subscribe(channel: imageShowChannel).listen(_onImageShow));

    // `clide draw --file <doc>` (T-318): the dispatcher lowers the doc to SVG
    // and publishes a 'draw' message; we inject the drawing card into the
    // conversation the user is looking at.
    _subs.add(ctx.messages.subscribe(channel: drawShowChannel).listen(_onDrawShow));

    // `clide icon show <name…>` (T-313): the dispatcher resolves the glyphs and
    // publishes an 'icon' message; we inject the glyph card.
    _subs.add(ctx.messages.subscribe(channel: iconShowChannel).listen(_onIconShow));

    // A sidebar "pick up" click (T-327) publishes the full ticket; inject it
    // into the active conversation as a user turn so Claude starts working it.
    _subs.add(ctx.messages.subscribe(publisher: 'builtin.tickets', channel: 'pick-up').listen(_onTicketPickUp));

    // `clide claude account set/unset/remove --purge` (T-480): the dispatcher
    // writes the registry then publishes here; only the UI layer can respawn
    // the workspace's panes onto the newly-bound account or delete a config dir.
    _subs.add(ctx.messages.subscribe(channel: accountActionChannel).listen(_onAccountAction));

    // A freshly-created project (T-488) announces itself once it's open; show the
    // per-repo account roadblock so the user binds it now (existing opens, which
    // never announce, are never prompted).
    _subs.add(ctx.messages.subscribe(channel: projectCreatedChannel).listen(_onProjectCreated));
  }

  void _onProjectCreated(Message m) {
    final dir = m.data['dir'] as String?;
    final ctx = _ctx;
    if (dir == null || ctx == null) return;
    final name = dir.split('/').where((s) => s.isNotEmpty).lastOrNull ?? dir;
    ctx.dialog.show<Object>((c, dismiss) => ClaudeAccountRoadblockDialog(projectName: name, onClose: dismiss));
  }

  /// Side-effects for the `claude account` verbs (T-480). The dispatcher does
  /// the registry write and publishes the action here; respawning panes,
  /// deleting a config dir, and (future) the login terminal pane are UI-layer
  /// concerns the Flutter-free handler can't do itself.
  void _onAccountAction(Message m) {
    switch (m.data['action'] as String?) {
      case 'set':
      case 'unset':
        final cwd = m.data['cwd'] as String?;
        final orch = _orchestrator;
        if (cwd != null && orch != null) unawaited(orch.respawnForWorkspace(cwd));
      case 'purge':
        final dir = m.data['dir'] as String?;
        if (dir != null) unawaited(_purgeAccountDir(dir));
      case 'login':
        final name = m.data['name'] as String?;
        final dir = m.data['dir'] as String?;
        final ctx = _ctx;
        // Host `CLAUDE_CONFIG_DIR=<dir> claude login` in a modal terminal pane
        // (T-485); the CLI owns the OAuth browser flow.
        if (name != null && dir != null && ctx != null) {
          ctx.dialog.show<Object>((c, dismiss) => ClaudeLoginDialog(name: name, dir: dir, cwd: _projectRoot, onClose: dismiss));
        }
    }
  }

  /// Delete a purged account's config dir (`remove --purge`). Guarded: only a
  /// `~/.claude-*` directory that is a direct child of the user's home is ever
  /// removed — never an arbitrary path, even though the dir came from our own
  /// registry. A `rm -rf` of the wrong dir is unrecoverable.
  Future<void> _purgeAccountDir(String dir) async {
    final home = Platform.environment['HOME'];
    if (home == null || !isPurgeableAccountDir(dir, home)) return;
    final d = Directory(dir);
    if (await d.exists()) await d.delete(recursive: true);
  }

  /// Hand a picked-up ticket to the active Claude session (T-327/T-339). The
  /// decision + transition live in [applyTicketPickUp] so they're testable
  /// without the activation machinery.
  void _onTicketPickUp(Message m) {
    final ctx = _ctx;
    if (ctx == null) return;
    unawaited(applyTicketPickUp(m.data, orchestrator: _orchestrator, ipc: ctx.ipc, messages: ctx.messages));
  }

  /// Close every session that doesn't belong to the newly-active workspace
  /// after an in-place project switch (T-269). The initial open (no previous
  /// root) and a no-op re-open are skipped. Panes rebind to the new repo on
  /// their own; this catches team/orphan sessions no pane owns.
  void _onProjectChanged(ProjectOpened e) {
    final prev = _projectRoot;
    _projectRoot = e.path;
    if (prev == null || prev == e.path) return;
    final orch = _orchestrator;
    if (orch == null) return;
    final stale = orch.sessions.where((m) => m.cwd != e.path).map((m) => m.id).toList();
    for (final id in stale) {
      unawaited(orch.close(id));
    }
  }

  /// Inject an [ImageMessage] from a published `image` bus message (T-249).
  /// Dropped silently if no live conversation is available — the CLI already
  /// reported success at publish time, and a missing pane is transient.
  void _onImageShow(Message m) {
    final path = m.data['path'] as String?;
    if (path == null || path.isEmpty) return;
    // `clide image show <path> --fullscreen` (T-252): open straight into the
    // lightbox instead of injecting an inline card.
    if (m.data['fullscreen'] == true) {
      _ctx?.dialog.show<Object>(
        (c, dismiss) => ClideLightbox(
          onDismiss: dismiss,
          child: Image(image: ClideFileImage(path), fit: BoxFit.contain),
        ),
      );
      return;
    }
    final target = _orchestrator?.byId('primary') ?? _orchestrator?.visibleSessions.firstOrNull;
    if (target == null) return;
    target.conversation.inject(
      ImageMessage(
        uuid: 'image-${DateTime.now().microsecondsSinceEpoch}',
        timestamp: DateTime.now(),
        isSidechain: false,
        path: path,
        caption: m.data['caption'] as String?,
        label: m.data['label'] as String?,
        description: m.data['description'] as String?,
      ),
    );
  }

  /// Inject an [IconMessage] from a published `icon` bus message (T-313).
  void _onIconShow(Message m) {
    final raw = m.data['entries'];
    if (raw is! List || raw.isEmpty) return;
    final entries = <IconEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final cp = item['codepoint'];
      if (cp is! int) continue;
      entries.add(
        IconEntry(
          codepoint: cp,
          name: item['name'] as String? ?? '',
          label: item['label'] as String?,
          description: item['description'] as String?,
          color: item['color'] as String?,
        ),
      );
    }
    if (entries.isEmpty) return;
    final target = _orchestrator?.byId('primary') ?? _orchestrator?.visibleSessions.firstOrNull;
    if (target == null) return;
    target.conversation.inject(
      IconMessage(
        uuid: 'icon-${DateTime.now().microsecondsSinceEpoch}',
        timestamp: DateTime.now(),
        isSidechain: false,
        entries: entries,
        color: m.data['color'] as String?,
      ),
    );
  }

  /// Inject a [DrawingMessage] from a published `draw` bus message (T-318).
  /// Dropped silently if no live conversation is available — the CLI already
  /// reported success at publish time, and a missing pane is transient.
  void _onDrawShow(Message m) {
    final svg = m.data['svg'] as String?;
    if (svg == null || svg.isEmpty) return;
    final target = _orchestrator?.byId('primary') ?? _orchestrator?.visibleSessions.firstOrNull;
    if (target == null) return;
    target.conversation.inject(
      DrawingMessage(
        uuid: 'draw-${DateTime.now().microsecondsSinceEpoch}',
        timestamp: DateTime.now(),
        isSidechain: false,
        svg: svg,
        label: m.data['label'] as String?,
        description: m.data['description'] as String?,
        source: m.data['source'] as String?,
      ),
    );
  }

  @override
  Future<void> deactivate() async {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    if (identical(activeSessionOrchestrator, _orchestrator)) activeSessionOrchestrator = null;
    _orchestrator?.dispose();
    _orchestrator = null;
    if (identical(activeClaudeConfig, _config)) activeClaudeConfig = null;
    _config?.dispose();
    _config = null;
  }

  /// Hard-reset command: close every clide-managed Claude session for this
  /// repo (primary + all secondaries + any team members). The user invokes
  /// this when they want a hard reset — after a Claude wedge or to start
  /// completely fresh. All sessions are torn down through the orchestrator
  /// (D-77); the primary will re-spawn and resume on the next pane build.
  /// Cycle the persisted activity fold level (T-235). Reads the current value
  /// from settings, advances none → tools → thinking → everything → none, and
  /// writes it back; the panes listen to settings and re-fold live.
  Future<IpcResponse> _cycleFoldLevel(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return IpcResponse.ok(id: '', data: const {});
    final current = foldLevelFromName(ctx.settings.get<String>(kActivityFoldLevelKey));
    final next = nextFoldLevel(current);
    await ctx.settings.set<String>(kActivityFoldLevelKey, next.name);
    return IpcResponse.ok(id: '', data: {'foldLevel': next.name});
  }

  Future<IpcResponse> _killAllSessions(List<String> args) async {
    final orch = _orchestrator;
    if (orch == null) return IpcResponse.ok(id: '', data: const {});

    // Close every tracked session through the orchestrator; this kills each
    // process and releases its resources. Panes will see their session gone
    // and surface an error / restart on next interaction.
    final ids = orch.sessions.map((m) => m.id).toList();
    for (final id in ids) {
      await orch.close(id);
    }

    return IpcResponse.ok(id: '', data: const {'status': 'killed'});
  }

  /// Open the session-storage manager: per-session transcript sizes, a total,
  /// and a user-driven cleanup (T-148). Enumerates the workspace's sessions
  /// and shows the modal; deletion happens inside the dialog.
  Future<IpcResponse> _manageStorage(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return IpcResponse.ok(id: '', data: const {});
    final resp = await ctx.ipc.request('files.root');
    final root = resp.ok ? resp.data['path'] as String? : null;
    final home = Platform.environment['HOME'];
    if (root == null || home == null) return IpcResponse.ok(id: '', data: const {});
    final dir = Directory('$home/.claude/projects/${root.replaceAll('/', '-')}');
    final sessions = await listSessions(dir);
    await ctx.dialog.show<Object>((c, dismiss) => SessionStorageDialog(dir: dir, sessions: sessions, onClose: dismiss));
    return IpcResponse.ok(id: '', data: const {'status': 'shown'});
  }
}
