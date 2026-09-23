import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:flutter/foundation.dart';

class TicketDetail {
  const TicketDetail({required this.ticket, this.parents = const [], this.decisions = const [], this.children = const []});
  final Map<String, Object?> ticket;
  final List<Map<String, Object?>> parents;
  final List<Map<String, Object?>> decisions;

  /// Direct children, open work first and closed last — see [orderChildren].
  final List<Map<String, Object?>> children;

  /// Statuses that count as finished; the detail view collapses these (T-595).
  static const closedStatuses = {'done', 'cancelled'};

  static bool isClosed(Map<String, Object?> child) => closedStatuses.contains(child['status']);

  /// Orders children for the detail view: in-progress work on top, then
  /// review, ready and backlog, closed tickets last. Ties keep pql's order.
  static List<Map<String, Object?>> orderChildren(List<Map<String, Object?>> children) {
    int rank(Object? status) => switch (status) {
      'in_progress' => 0,
      'review' => 1,
      'ready' => 2,
      'backlog' => 3,
      'done' => 5,
      'cancelled' => 6,
      _ => 4,
    };
    final indexed = [for (var i = 0; i < children.length; i++) (i, children[i])];
    indexed.sort((a, b) {
      final byStatus = rank(a.$2['status']).compareTo(rank(b.$2['status']));
      return byStatus != 0 ? byStatus : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

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
  TicketDetailController({required this.ipc, required this.messages}) {
    // Load on 'load' — the single channel the retained ReaderNav emits
    // (T-199). The extension reveals the tab; the nav owns history.
    _sub = messages.subscribe(publisher: 'builtin.tickets', channel: 'load').listen(_onLoad);
  }

  final DaemonClient ipc;
  final MessageBus messages;
  StreamSubscription<Message>? _sub;

  TicketDetail? _detail;
  TicketDetail? get detail => _detail;

  bool _loading = false;
  bool get loading => _loading;

  void _onLoad(Message msg) {
    final id = msg.data['id'] as String?;
    if (id != null) unawaited(load(id));
  }

  Future<void> load(String id) async {
    _loading = true;
    notifyListeners();

    final resp = await ipc.request('pql.tickets.show', args: {'id': id, 'withContext': true, 'withChildren': true});
    if (!resp.ok) {
      _loading = false;
      notifyListeners();
      return;
    }

    final ticket = resp.data;
    final ancestors = (ticket['ancestors'] as List?)?.cast<Map<String, Object?>>() ?? const [];
    final decisions = (ticket['decisions'] as List?)?.cast<Map<String, Object?>>() ?? const [];
    final children = (ticket['children'] as List?)?.cast<Map<String, Object?>>() ?? const [];

    _detail = TicketDetail(ticket: ticket, parents: ancestors, decisions: decisions, children: TicketDetail.orderChildren(children));
    _loading = false;
    messages.publish('builtin.tickets', 'focus', {'id': id});
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
