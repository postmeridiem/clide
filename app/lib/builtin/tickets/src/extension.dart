import 'package:clide_app/extension/extension.dart';

/// Tier-reserved stub. Will surface a sidebar tab (filtered list) + a
/// workspace tab (kanban board) + commands (`tickets.open`,
/// `tickets.new`, `tickets.move`, `tickets.block`). Data source:
/// `pql ticket …`. Ticket persistence strategy open at `Q-022`.
class TicketsExtension extends ClideExtension {
  @override
  String get id => 'builtin.tickets';
  @override
  String get title => 'Tickets';
  @override
  String get version => '0.0.0-stub';
  @override
  List<String> get dependsOn => const [];
  @override
  List<ContributionPoint> get contributions => const [];
}
