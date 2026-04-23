import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:flutter/foundation.dart';

class TicketDetail {
  const TicketDetail({required this.ticket, this.parents = const [], this.decisions = const []});
  final Map<String, Object?> ticket;
  final List<Map<String, Object?>> parents;
  final List<Map<String, Object?>> decisions;

  String get id => ticket['id'] as String? ?? '';
  String get title => ticket['title'] as String? ?? '';
  String? get type => ticket['type'] as String?;
  String? get status => ticket['status'] as String?;
  String? get priority => ticket['priority'] as String?;
  String? get description => ticket['description'] as String?;
  String? get parentId => ticket['parent_id'] as String?;
  String? get decisionRef => ticket['decision_ref'] as String?;
  String? get assignedTo => ticket['assigned_to'] as String?;
}

class TicketDetailController extends ChangeNotifier {
  TicketDetailController({required this.ipc, required this.messages, required this.panels}) {
    _sub = messages.subscribe(publisher: 'builtin.tickets', channel: 'selection').listen(_onSelection);
  }

  final DaemonClient ipc;
  final MessageBus messages;
  final PanelRegistry panels;
  StreamSubscription<Message>? _sub;

  TicketDetail? _detail;
  TicketDetail? get detail => _detail;

  bool _loading = false;
  bool get loading => _loading;

  void _onSelection(Message msg) {
    final id = msg.data['id'] as String?;
    if (id != null) {
      panels.activateTab(Slots.contextPanel, 'tickets.detail');
      unawaited(load(id));
    }
  }

  Future<void> load(String id) async {
    _loading = true;
    notifyListeners();

    final resp = await ipc.request('pql.tickets.show', args: {'id': id});
    if (!resp.ok) {
      _loading = false;
      notifyListeners();
      return;
    }

    final ticket = resp.data;
    final parents = <Map<String, Object?>>[];
    final decisions = <Map<String, Object?>>[];

    // Walk parent chain
    var pid = ticket['parent_id'] as String?;
    while (pid != null) {
      final pr = await ipc.request('pql.tickets.show', args: {'id': pid});
      if (!pr.ok) break;
      parents.add(pr.data);
      pid = pr.data['parent_id'] as String?;
    }

    // Collect decision refs from ticket and parents
    final refs = <String>{};
    final dr = ticket['decision_ref'] as String?;
    if (dr != null) refs.add(dr);
    for (final p in parents) {
      final pdr = p['decision_ref'] as String?;
      if (pdr != null) refs.add(pdr);
    }

    for (final ref in refs) {
      final dr = await ipc.request('pql.decisions.show', args: {'id': ref});
      if (dr.ok) decisions.add(dr.data);
    }

    _detail = TicketDetail(ticket: ticket, parents: parents, decisions: decisions);
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
