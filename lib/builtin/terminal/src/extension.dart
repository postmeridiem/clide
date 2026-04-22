import 'package:clide/builtin/terminal/src/terminal_pane.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

/// General-purpose terminal pane. Spawns `$SHELL` under a daemon-owned
/// PTY; no Claude-specific behaviour. For the Claude pane with session
/// persistence + primary-per-repo semantics see `builtin.claude` (+
/// D-041).
class TerminalExtension extends ClideExtension {
  @override
  String get id => 'builtin.terminal';
  @override
  String get title => 'Terminal';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'terminal.pane',
          slot: Slots.workspace,
          title: 'Terminal',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: 100,
          build: (_) => const TerminalPane(),
        ),
      ];
}
