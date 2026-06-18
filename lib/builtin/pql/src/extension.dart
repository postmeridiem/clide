import 'package:clide/builtin/pql/src/backlinks_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';

class PqlExtension extends ClideExtension {
  @override
  String get id => 'builtin.pql';
  @override
  String get title => 'pql';
  @override
  String get version => '0.3.0';
  @override
  List<String> get dependsOn => const [];

  // The pql search/query/markdown surface moved into the unified Search
  // tab (T-201); this extension keeps only the Backlinks context panel.
  @override
  List<ContributionPoint> get contributions => [
    TabContribution(
      id: 'pql.backlinks',
      slot: Slots.contextPanel,
      title: 'Links',
      titleKey: 'tab.links.title',
      i18nNamespace: id,
      icon: PhosphorIcons.byName('link'),
      priority: -80,
      build: (_) => const BacklinksView(),
    ),
  ];
}
