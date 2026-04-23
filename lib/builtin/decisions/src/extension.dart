import 'dart:async';

import 'package:clide/builtin/decisions/src/decision_detail_view.dart';
import 'package:clide/builtin/decisions/src/decisions_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/events/message_bus.dart';

class DecisionsExtension extends ClideExtension {
  @override
  String get id => 'builtin.decisions';
  @override
  String get title => 'Decisions';
  @override
  String get version => '0.3.0';
  @override
  List<String> get dependsOn => const [];

  ClideExtensionContext? _ctx;
  StreamSubscription<Message>? _selectionSub;
  bool _detailSpawned = false;

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

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    _selectionSub = ctx.messages.subscribe(publisher: id, channel: 'selection').listen(_onSelection);
  }

  @override
  Future<void> deactivate() async {
    _selectionSub?.cancel();
    _despawnDetail();
  }

  void _onSelection(Message msg) {
    final ctx = _ctx;
    if (ctx == null) return;
    if (!_detailSpawned) {
      ctx.panels.contribute(TabContribution(
        id: 'decisions.detail',
        slot: Slots.contextPanel,
        title: 'Decision',
        priority: -50,
        build: (_) => const DecisionDetailView(),
      ));
      _detailSpawned = true;
    }
    ctx.panels.activateTab(Slots.contextPanel, 'decisions.detail');
  }

  void _despawnDetail() {
    if (_detailSpawned) {
      _ctx?.panels.uncontribute('decisions.detail');
      _detailSpawned = false;
    }
  }
}
