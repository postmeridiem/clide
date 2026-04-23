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
  String get version => '0.5.0';
  @override
  List<String> get dependsOn => const [];

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
