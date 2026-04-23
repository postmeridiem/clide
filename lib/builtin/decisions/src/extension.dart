import 'dart:async';

import 'package:clide/builtin/decisions/src/decision_detail_view.dart';
import 'package:clide/builtin/decisions/src/decisions_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

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
  VoidCallback? _panelListener;
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
    _panelListener = () {
      if (_detailSpawned && ctx.panels.activeTabIn(Slots.contextPanel) != 'decisions.detail') {
        _despawnDetail();
      }
    };
    ctx.panels.addListener(_panelListener!);
  }

  @override
  Future<void> deactivate() async {
    _selectionSub?.cancel();
    if (_panelListener != null) _ctx?.panels.removeListener(_panelListener!);
    _despawnDetail();
  }

  void _onSelection(Message msg) {
    final ctx = _ctx;
    if (ctx == null) return;
    final selectedId = msg.data['id'] as String?;
    if (selectedId == null) return;

    if (_detailSpawned) {
      _despawnDetail();
    }
    ctx.panels.contribute(TabContribution(
      id: 'decisions.detail',
      slot: Slots.contextPanel,
      title: 'Decision',
      priority: -50,
      build: (_) => DecisionDetailView(initialId: selectedId),
    ));
    _detailSpawned = true;
    ctx.panels.activateTab(Slots.contextPanel, 'decisions.detail');
  }

  void _despawnDetail() {
    if (_detailSpawned) {
      _ctx?.panels.uncontribute('decisions.detail');
      _detailSpawned = false;
    }
  }
}
