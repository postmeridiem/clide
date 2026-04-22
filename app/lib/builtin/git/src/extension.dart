import 'package:clide_app/builtin/git/src/git_panel_view.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';

class GitExtension extends ClideExtension {
  @override
  String get id => 'builtin.git';
  @override
  String get title => 'Git';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const ['builtin.diff'];

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'git.panel',
          slot: Slots.sidebar,
          title: 'Git',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: -80,
          build: (_) => const GitPanelView(),
        ),
      ];
}
