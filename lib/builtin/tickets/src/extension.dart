import 'dart:async';

import 'package:clide/builtin/tickets/src/ticket_detail_view.dart';
import 'package:clide/builtin/tickets/src/tickets_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

class TicketsExtension extends ClideExtension {
  @override
  String get id => 'builtin.tickets';
  @override
  String get title => 'Tickets';
  @override
  String get version => '0.4.0';
  @override
  List<String> get dependsOn => const [];

  ClideExtensionContext? _ctx;
  StreamSubscription<Message>? _selectionSub;
  VoidCallback? _panelListener;
  bool _detailSpawned = false;

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'tickets.panel',
          slot: Slots.sidebar,
          title: 'Tickets',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: -10,
          build: (_) => const TicketsView(),
        ),
      ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    _selectionSub = ctx.messages.subscribe(publisher: id, channel: 'selection').listen(_onSelection);
    _panelListener = () {
      if (_detailSpawned && ctx.panels.activeTabIn(Slots.contextPanel) != 'tickets.detail') {
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
      id: 'tickets.detail',
      slot: Slots.contextPanel,
      title: 'Ticket',
      priority: -60,
      build: (_) => TicketDetailView(initialId: selectedId),
    ));
    _detailSpawned = true;
    ctx.panels.activateTab(Slots.contextPanel, 'tickets.detail');
  }

  void _despawnDetail() {
    if (_detailSpawned) {
      _ctx?.panels.uncontribute('tickets.detail');
      _detailSpawned = false;
    }
  }
}
