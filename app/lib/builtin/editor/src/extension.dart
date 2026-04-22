import 'package:clide_app/builtin/editor/src/editor_view.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';

/// Tier-2 editor pane. Contributes a single workspace tab that
/// renders the daemon's active buffer. Multi-file tabs live in the
/// follow-up plan; today the pane is one-at-a-time.
class EditorExtension extends ClideExtension {
  @override
  String get id => 'builtin.editor';
  @override
  String get title => 'Editor';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'editor.active',
          slot: Slots.workspace,
          title: 'Editor',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: 80, // between Claude (90) and welcome (-100)
          build: (_) => const EditorView(),
        ),
      ];
}
