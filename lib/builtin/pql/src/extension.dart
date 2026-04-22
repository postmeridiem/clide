import 'package:clide/builtin/pql/src/backlinks_view.dart';
import 'package:clide/builtin/pql/src/pql_panel_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

class PqlExtension extends ClideExtension {
  @override
  String get id => 'builtin.pql';
  @override
  String get title => 'pql';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'pql.panel',
          slot: Slots.sidebar,
          title: 'pql',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: -60,
          build: (_) => const PqlPanelView(),
        ),
        TabContribution(
          id: 'pql.backlinks',
          slot: Slots.contextPanel,
          title: 'Links',
          titleKey: 'tab.links',
          i18nNamespace: id,
          priority: -80,
          build: (_) => const BacklinksView(),
        ),
      ];
}
