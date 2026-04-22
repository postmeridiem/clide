import 'package:clide/builtin/tickets/src/tickets_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

class TicketsExtension extends ClideExtension {
  @override
  String get id => 'builtin.tickets';
  @override
  String get title => 'Tickets';
  @override
  String get version => '0.1.0';
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
          priority: -10,
          build: (_) => const TicketsView(),
        ),
      ];
}
