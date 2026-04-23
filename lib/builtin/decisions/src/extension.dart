import 'dart:async';

import 'package:clide/builtin/decisions/src/decision_detail_view.dart';
import 'package:clide/builtin/decisions/src/decisions_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/widgets/widgets.dart';

class DecisionsExtension extends ClideExtension {
  @override
  String get id => 'builtin.decisions';
  @override
  String get title => 'Decisions';
  @override
  String get version => '0.6.0';
  @override
  List<String> get dependsOn => const [];

  StreamSubscription<Message>? _sub;

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _sub = ctx.messages.subscribe(publisher: id, channel: 'selection').listen((msg) {
      final selectedId = msg.data['id'] as String?;
      if (selectedId == null) return;
      ctx.panels.uncontribute('decisions.detail');
      ctx.panels.contribute(TabContribution(
        id: 'decisions.detail',
        slot: Slots.contextPanel,
        title: 'Decision',
        icon: PhosphorIcons.lightbulb,
        build: (_) => DecisionDetailView(initialId: selectedId),
      ));
      ctx.panels.activateTab(Slots.contextPanel, 'decisions.detail');
    });
  }

  @override
  Future<void> deactivate() async => _sub?.cancel();

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
