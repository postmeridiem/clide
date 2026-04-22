import 'package:clide/builtin/graph/src/graph_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

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
          titleKey: 'tab.graph',
          i18nNamespace: id,
          priority: -80,
          build: (_) => const GraphView(),
        ),
      ];
}
