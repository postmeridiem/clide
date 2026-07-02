import 'package:clide/builtin/graph/src/graph_panel.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';

class GraphExtension extends ClideExtension {
  @override
  String get id => 'builtin.graph';
  @override
  String get title => 'Graph';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const ['builtin.pql'];

  @override
  List<ContributionPoint> get contributions => [
    TabContribution(
      id: 'graph.view',
      slot: Slots.contextPanel,
      title: 'Graph',
      titleKey: 'tab.graph.title',
      i18nNamespace: id,
      icon: PhosphorIcons.byName('graph'),
      priority: -70,
      build: (_) => const GraphPanel(),
    ),
  ];
}
