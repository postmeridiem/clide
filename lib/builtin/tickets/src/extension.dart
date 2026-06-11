import 'dart:async';

import 'package:clide/builtin/tickets/src/ticket_detail_view.dart';
import 'package:clide/builtin/tickets/src/tickets_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
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
    // Ensure the retained nav exists so it records selections + emits
    // loads whether or not the detail view is mounted (T-199/D-81).
    ctx.readerNav.navFor(id, dataKey: 'id');
    // Reveal the static detail tab on selection — no per-click
    // uncontribute/contribute churn (the T-188 anti-pattern). The nav
    // owns load + history.
    _sub = ctx.messages.subscribe(publisher: id, channel: 'selection').listen((msg) {
      if (msg.data['id'] is! String) return;
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
      icon: PhosphorIcons.byName('ticket'),
      build: (_) => const TicketsView(),
    ),
    TabContribution(
      id: 'tickets.detail',
      slot: Slots.contextPanel,
      title: 'Ticket',
      icon: PhosphorIcons.byName('ticket'),
      build: (_) => const TicketDetailView(),
    ),
  ];
}
