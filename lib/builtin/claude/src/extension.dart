import 'package:clide/clide.dart';
import 'package:clide/builtin/claude/src/claude_session_host.dart';
import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:clide/builtin/claude/src/tmux_session.dart' as tmux;
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
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

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'claude.primary',
          slot: Slots.workspace,
          title: 'Claude',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: 90,
          build: (_) => ClaudeSessionHost(key: _hostKey),
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
      ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    // Cold-start reap: kill any leftover secondary tmux sessions from
    // a previous run. D-41's "secondary numbering resets between
    // clide runs" only holds if the leftovers are gone before the new
    // run starts. Doing this in activate (rather than the previous
    // run's deactivate) guarantees cleanup even after an abrupt exit
    // — Flutter's deactivate hook only fires on explicit extension
    // teardown, not on app quit / kill -9 / OOM.
    final primary = await _primarySessionName();
    if (primary != null) await tmux.reapSecondaries(primary);
  }

  @override
  Future<void> deactivate() async {
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
