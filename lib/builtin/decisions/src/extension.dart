import 'package:clide/builtin/decisions/src/decision_detail_view.dart';
import 'package:clide/builtin/decisions/src/decisions_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';

class DecisionsExtension extends ClideExtension {
  @override
  String get id => 'builtin.decisions';
  @override
  String get title => 'Decisions';
  @override
  String get version => '0.5.0';
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
          icon: PhosphorIcons.lightbulb,
          build: (_) => const DecisionsView(),
        ),
        TabContribution(
          id: 'decisions.detail',
          slot: Slots.contextPanel,
          title: 'Decision',
          icon: PhosphorIcons.lightbulb,
          build: (_) => const DecisionDetailView(),
        ),
      ];
}
