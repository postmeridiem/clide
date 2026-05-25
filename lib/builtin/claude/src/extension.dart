import 'dart:async';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/claude_session_host.dart';
import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/pane_context_status.dart';
import 'package:clide/builtin/claude/src/claude_meta_sidebar.dart';
import 'package:clide/builtin/claude/src/session_index.dart';
import 'package:clide/builtin/claude/src/session_storage.dart';
import 'package:clide/builtin/claude/src/team_observer.dart';
import 'package:clide/builtin/claude/src/team_panel_host.dart';
import 'package:clide/builtin/claude/src/tmux_session.dart' as tmux;
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

  TeamObserver? _observer;
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
          title: 'Claude: kill all tmux sessions for this repo',
          run: _killAllSessions,
        ),
        CommandContribution(
          id: 'claude.session-storage',
          command: 'claude.session-storage',
          title: 'Claude: session storage (disk usage + cleanup)',
          run: _manageStorage,
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
        StatusItemContribution(
          id: 'claude.status-context',
          priority: 50,
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

    // Cold-start reap: kill any leftover secondary tmux sessions from
    // a previous run. D-41's "secondary numbering resets between
    // clide runs" only holds if the leftovers are gone before the new
    // run starts. Doing this in activate (rather than the previous
    // run's deactivate) guarantees cleanup even after an abrupt exit
    // — Flutter's deactivate hook only fires on explicit extension
    // teardown, not on app quit / kill -9 / OOM.
    final primary = await _primarySessionName();
    if (primary != null) await tmux.reapSecondaries(primary);

    // Observe a tmux agent team for the open workspace (T-139/T-140). The
    // observer emits TeamMemberJoined/Left, which TeamPanelHost renders as
    // teammate tiles. Restart it as the project changes.
    if (ctx.project.current != null) _restartObserver(ctx.project.current!.path);
    _subs.add(ctx.events.on<ProjectOpened>().listen((e) => _restartObserver(e.path)));
    _subs.add(ctx.events.on<ProjectClosed>().listen((_) => _stopObserver()));
  }

  void _restartObserver(String workspacePath) {
    final ctx = _ctx;
    if (ctx == null) return;
    unawaited(_observer?.dispose());
    _observer = TeamObserver(
      workspacePath: workspacePath,
      events: ctx.events,
      messages: ctx.messages,
    )..start();
  }

  void _stopObserver() {
    unawaited(_observer?.dispose());
    _observer = null;
  }

  @override
  Future<void> deactivate() async {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _stopObserver();
    if (identical(activeSessionOrchestrator, _orchestrator)) activeSessionOrchestrator = null;
    _orchestrator?.dispose();
    _orchestrator = null;
    if (identical(activeClaudeConfig, _config)) activeClaudeConfig = null;
    _config?.dispose();
    _config = null;
    // Best-effort cleanup on explicit extension teardown. The cold-
    // start reap in activate is the actual safety net.
    final primary = await _primarySessionName();
    if (primary != null) await tmux.reapSecondaries(primary);
  }

  /// Hard-reset command: kill every clide-claude tmux session for this
  /// repo, primary included. The user invokes this when they want to
  /// start over — typically after a tmux/Claude wedge.
  Future<IpcResponse> _killAllSessions(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return IpcResponse.ok(id: '', data: const {});

    // Close the UI panes first so they don't try to talk to a tmux
    // server that's about to lose their sessions.
    final resp = await ctx.ipc.request('pane.list');
    if (resp.ok) {
      final panes = resp.data['panes'];
      if (panes is List) {
        for (final p in panes) {
          if (p is Map && p['kind'] == 'claude') {
            final id = p['id'] as String?;
            if (id != null) {
              await ctx.ipc.request('pane.close', args: {'id': id});
            }
          }
        }
      }
    }

    // Then kill the server-side sessions, primary included.
    final primary = await _primarySessionName();
    if (primary != null) await tmux.killAllForRepo(primary);

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

  Future<String?> _primarySessionName() async {
    final ctx = _ctx;
    if (ctx == null) return null;
    final resp = await ctx.ipc.request('files.root');
    if (!resp.ok) return null;
    final root = resp.data['path'] as String?;
    if (root == null) return null;
    return primarySessionName(root);
  }
}
