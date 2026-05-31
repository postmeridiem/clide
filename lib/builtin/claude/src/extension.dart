import 'dart:async';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/claude_session_host.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/pane_context_status.dart';
import 'package:clide/builtin/claude/src/claude_meta_sidebar.dart';
import 'package:clide/builtin/claude/src/session_index.dart';
import 'package:clide/builtin/claude/src/session_storage.dart';
import 'package:clide/builtin/claude/src/team_chat_sidebar.dart' show TeamChatPane;
import 'package:clide/builtin/claude/src/team_panel_host.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ClaudeExtension extends ClideExtension {
  @override
  String get id => 'builtin.claude';
  @override
  String get title => 'Claude';
  @override
  String get version => '0.2.0';
  @override
  List<String> get dependsOn => const [];

  ClideExtensionContext? _ctx;
  final GlobalKey<ClaudeSessionHostState> _hostKey = GlobalKey();

  ClaudeConfig? _config;
  ClaudeSessionOrchestrator? _orchestrator;
  final List<StreamSubscription<dynamic>> _subs = [];

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
          run: (_) async {
            _hostKey.currentState?.addSecondary();
            return IpcResponse.ok(id: '', data: const {'status': 'spawned'});
          },
        ),
        CommandContribution(
          id: 'claude.kill-all-sessions',
          command: 'claude.kill-all-sessions',
          title: 'Claude: kill all sessions for this repo',
          run: _killAllSessions,
        ),
        CommandContribution(
          id: 'claude.session-storage',
          command: 'claude.session-storage',
          title: 'Claude: session storage (disk usage + cleanup)',
          run: _manageStorage,
        ),
        // T-171: agent roster controls (D-6 CLI/UI parity).
        // Usage: clide claude.agent.show <sessionId>
        CommandContribution(
          id: 'claude.agent.show',
          command: 'claude.agent.show',
          title: 'Claude: show an agent session pane',
          run: (args) async {
            final id = args.firstOrNull;
            if (id == null) return IpcResponse.ok(id: '', data: const {'error': 'missing session id'});
            _orchestrator?.show(id);
            return IpcResponse.ok(id: '', data: {'id': id, 'status': 'shown'});
          },
        ),
        CommandContribution(
          id: 'claude.agent.hide',
          command: 'claude.agent.hide',
          title: 'Claude: hide an agent session pane',
          run: (args) async {
            final id = args.firstOrNull;
            if (id == null) return IpcResponse.ok(id: '', data: const {'error': 'missing session id'});
            _orchestrator?.hide(id);
            return IpcResponse.ok(id: '', data: {'id': id, 'status': 'hidden'});
          },
        ),
        CommandContribution(
          id: 'claude.agent.close',
          command: 'claude.agent.close',
          title: 'Claude: close (kill) an agent session',
          run: (args) async {
            final id = args.firstOrNull;
            if (id == null) return IpcResponse.ok(id: '', data: const {'error': 'missing session id'});
            await _orchestrator?.close(id);
            return IpcResponse.ok(id: '', data: {'id': id, 'status': 'closed'});
          },
        ),
        CommandContribution(
          id: 'claude.agent.mute',
          command: 'claude.agent.mute',
          title: 'Claude: mute broker delivery to an agent session',
          run: (args) async {
            final id = args.firstOrNull;
            if (id == null) return IpcResponse.ok(id: '', data: const {'error': 'missing session id'});
            _orchestrator?.mute(id);
            return IpcResponse.ok(id: '', data: {'id': id, 'status': 'muted'});
          },
        ),
        CommandContribution(
          id: 'claude.agent.unmute',
          command: 'claude.agent.unmute',
          title: 'Claude: unmute broker delivery to an agent session',
          run: (args) async {
            final id = args.firstOrNull;
            if (id == null) return IpcResponse.ok(id: '', data: const {'error': 'missing session id'});
            _orchestrator?.unmute(id);
            return IpcResponse.ok(id: '', data: {'id': id, 'status': 'unmuted'});
          },
        ),
        // Usage: clide claude.agent.inject-message <sessionId> <text...>
        CommandContribution(
          id: 'claude.agent.inject-message',
          command: 'claude.agent.inject-message',
          title: 'Claude: inject a text turn into an agent session',
          run: (args) async {
            final id = args.firstOrNull;
            if (id == null) return IpcResponse.ok(id: '', data: const {'error': 'missing session id'});
            final text = args.skip(1).join(' ');
            if (text.isEmpty) return IpcResponse.ok(id: '', data: const {'error': 'missing message text'});
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
          run: (args) async {
            final id = args.firstOrNull;
            if (id == null) return IpcResponse.ok(id: '', data: const {'error': 'missing session id'});
            final mode = args.length >= 2 ? args[1] : null;
            if (mode == null) return IpcResponse.ok(id: '', data: const {'error': 'missing mode (default|acceptEdits|plan|bypassPermissions)'});
            const valid = {'default', 'acceptEdits', 'plan', 'bypassPermissions'};
            if (!valid.contains(mode)) {
              return IpcResponse.ok(id: '', data: {'error': 'unknown mode "$mode"; use one of: ${valid.join(', ')}'});
            }
            _orchestrator?.byId(id)?.session.setPermissionMode(mode);
            return IpcResponse.ok(id: '', data: {'id': id, 'mode': mode, 'status': 'sent'});
          },
        ),
        // Usage: clide claude.task.reassign <taskId> <toSessionId>
        CommandContribution(
          id: 'claude.task.reassign',
          command: 'claude.task.reassign',
          title: 'Claude: reassign a shared task to an agent',
          run: (args) async {
            if (args.length < 2) return IpcResponse.ok(id: '', data: const {'error': 'usage: <taskId> <sessionId>'});
            final taskId = args[0];
            final toId = args[1];
            final ok = _orchestrator?.broker.reassignTask(taskId, toId) ?? false;
            return IpcResponse.ok(id: '', data: {'taskId': taskId, 'toId': toId, 'ok': ok});
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
          run: (args) async {
            if (args.isEmpty) return IpcResponse.ok(id: '', data: const {'error': 'usage: [@name] <text>'});
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
            return IpcResponse.ok(id: '', data: {'status': 'posted', if (recipient != null) 'to': recipient});
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
          run: (args) async {
            final sourceId = args.firstOrNull;
            if (sourceId == null) {
              return IpcResponse.ok(id: '', data: const {'error': 'usage: claude.agent.fork <sourceSessionId> [<cwd>]'});
            }
            final orch = _orchestrator;
            if (orch == null) {
              return IpcResponse.ok(id: '', data: const {'error': 'orchestrator unavailable'});
            }
            final source = orch.byId(sourceId);
            if (source == null) {
              return IpcResponse.ok(id: '', data: {'error': 'unknown session "$sourceId"'});
            }
            final cwd = args.length >= 2 ? args[1] : source.cwd;
            final forkId = 'fork:$sourceId-${DateTime.now().millisecondsSinceEpoch}';
            await orch.spawn(SpawnSpec(
              id: forkId,
              role: 'fork of $sourceId',
              sessionId: forkId,
              cwd: cwd,
              forkSourceSessionId: source.sessionId,
            ));
            return IpcResponse.ok(id: '', data: {'forkId': forkId, 'sourceId': sourceId, 'status': 'spawned'});
          },
        ),
        // Always-pickable left-panel tab: Claude activity (from
        // stats-cache.json) + the team roster when a team is running (T-141).
        TabContribution(
          id: 'claude.meta',
          slot: Slots.sidebar,
          title: 'Activity',
          icon: PhosphorIcons.robot,
          priority: 60,
          build: (_) => const ClaudeMetaSidebar(),
        ),
        // In-pane status slot (T-145): the active Claude pane publishes
        // its model · permission-mode · context line here.
        // flex: 1 → StatusbarHost wraps this in Flexible(loose) so the slot
        // yields width under pressure and ClideMarquee scrolls (T-160).
        StatusItemContribution(
          id: 'claude.status-context',
          priority: 50,
          flex: 1,
          build: (_) => const PaneContextStatusItem(),
        ),
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
    // session outlives its pane and is shared across surfaces.
    _orchestrator = ClaudeSessionOrchestrator();
    activeSessionOrchestrator = _orchestrator;
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
    await ctx.dialog.show<Object>(
      (c, dismiss) => SessionStorageDialog(dir: dir, sessions: sessions, onClose: dismiss),
    );
    return IpcResponse.ok(id: '', data: const {'status': 'shown'});
  }
}
