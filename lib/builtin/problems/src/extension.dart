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
        TabContribution(
          id: 'problems.panel',
          slot: Slots.sidebar,
          title: 'Problems',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: -50,
          build: (_) => const ProblemsView(),
        ),
      ];
}
