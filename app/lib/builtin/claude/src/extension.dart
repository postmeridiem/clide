import 'package:clide/clide.dart';
import 'package:clide_app/builtin/claude/src/claude_pane.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';

/// Claude pane. Primary per repo (tmux-persisted per D-041); optional
/// secondaries spawned via the `claude.new-secondary` command.
class ClaudeExtension extends ClideExtension {
  @override
  String get id => 'builtin.claude';
  @override
  String get title => 'Claude';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'claude.primary',
          slot: Slots.workspace,
          title: 'Claude',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: 90, // just before terminal (100)
          build: (_) => const ClaudePane(isPrimary: true),
        ),
        CommandContribution(
          id: 'claude.new-secondary',
          command: 'claude.new-secondary',
          title: 'Claude: open a secondary session',
          run: (_) async {
            // Secondary spawn is a UI-side concern (tab creation in
            // the workspace slot). Returning OK signals the palette
            // that the command exists; wiring the workspace-slot tab
            // manager to open `ClaudePane(isPrimary: false,
            // secondaryIndex: N)` on this command lands in a follow-up.
            // D-041 policy is captured in the decision record either
            // way.
            return IpcResponse.ok(
              id: '',
              data: const {
                'status': 'accepted',
                'note': 'UI-side tab manager wires this up in a '
                    'follow-up commit.',
              },
            );
          },
        ),
      ];
}
