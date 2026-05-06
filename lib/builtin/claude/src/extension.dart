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
  }

  @override
  Future<void> deactivate() async {
    await _killAllSessions([]);
  }

  Future<IpcResponse> _killAllSessions(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return IpcResponse.ok(id: '', data: const {});
    final resp = await ctx.ipc.request('pane.list');
    if (!resp.ok) return resp;
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
    return IpcResponse.ok(id: '', data: const {'status': 'killed'});
  }
}
