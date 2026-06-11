import 'package:clide/builtin/problems/src/problems_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

class ProblemsExtension extends ClideExtension {
  @override
  String get id => 'builtin.problems';
  @override
  String get title => 'Problems';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const ['builtin.pql'];

  @override
  List<ContributionPoint> get contributions => [
    // Moved out of the sidebar into the bottom dock (D-87): no duplication,
    // and the dock's width fits `severity · file:line · message` rows.
    TabContribution(
      id: 'problems.panel',
      slot: Slots.dock,
      title: 'Problems',
      titleKey: 'tab.title',
      i18nNamespace: id,
      priority: -50,
      build: (_) => const ProblemsView(),
    ),
  ];
}
