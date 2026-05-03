import 'dart:async';

import 'package:clide/builtin/tickets/src/ticket_detail_view.dart';
import 'package:clide/builtin/tickets/src/tickets_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/widgets/widgets.dart';

class TicketsExtension extends ClideExtension {
  @override
  String get id => 'builtin.tickets';
  @override
  String get title => 'Tickets';
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
      ctx.panels.uncontribute('tickets.detail');
      ctx.panels.contribute(TabContribution(
        id: 'tickets.detail',
        slot: Slots.contextPanel,
        title: 'Ticket',
        icon: PhosphorIcons.ticket,
        build: (_) => TicketDetailView(initialId: selectedId),
      ));
      ctx.arrangement.setVisible(Slots.contextPanel, true);
      ctx.arrangement.setCollapsed(Slots.contextPanel, false);
      ctx.panels.activateTab(Slots.contextPanel, 'tickets.detail');
    });
  }

  @override
  Future<void> deactivate() async => _sub?.cancel();

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'tickets.panel',
          slot: Slots.sidebar,
          title: 'Tickets',
          titleKey: 'tab.title',
          i18nNamespace: id,
          icon: PhosphorIcons.ticket,
          build: (_) => const TicketsView(),
        ),
        TabContribution(
          id: 'tickets.detail',
          slot: Slots.contextPanel,
          title: 'Ticket',
          icon: PhosphorIcons.ticket,
          build: (_) => const TicketDetailView(),
        ),
      ];
}
