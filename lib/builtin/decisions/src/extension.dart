import 'package:clide/builtin/decisions/src/decisions_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

class DecisionsExtension extends ClideExtension {
  @override
  String get id => 'builtin.decisions';
  @override
  String get title => 'Decisions';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'decisions.panel',
          slot: Slots.sidebar,
          title: 'Decisions',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: -20,
          build: (_) => const DecisionsView(),
        ),
      ];
}
