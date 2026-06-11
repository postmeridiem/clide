/// Sidebar "pick up" handling (T-327/T-339): inject a ticket's prompt into the
/// active Claude session and, on acceptance, advance the ticket to in_progress.
///
/// Kept out of `extension.dart` so it's unit-testable without dragging the whole
/// (UI-wiring) extension into instrumentation.
library;

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/kernel/kernel.dart';

/// Statuses a pick-up may advance from: a not-yet-started ticket. Picking up a
/// ticket that's already `in_progress`/`review`/`done`/`cancelled` injects the
/// prompt but leaves the status alone, so a re-pick-up never drags it backwards
/// or reopens it (T-339).
const kPickUpStartableStatuses = {'backlog', 'ready'};

/// Inject a picked-up ticket's prompt into the active session (the `primary`
/// lead, else the first visible one) and, on acceptance from a not-yet-started
/// ticket, advance it to `in_progress` and publish a `changed` so the sidebar
/// refreshes (T-327/T-339). Returns whether a live session accepted the prompt.
///
/// With no live session there's no injection and no state change — a quiet
/// no-op.
Future<bool> applyTicketPickUp(
  Map<String, Object?> data, {
  required ClaudeSessionOrchestrator? orchestrator,
  required DaemonClient ipc,
  required MessageBus messages,
}) async {
  final prompt = data['prompt'] as String?;
  if (prompt == null || prompt.isEmpty) return false;
  final target = orchestrator?.byId('primary') ?? orchestrator?.visibleSessions.firstOrNull;
  if (target == null) return false; // no live session → quiet no-op, no state change
  orchestrator!.injectMessage(target.id, prompt);

  final id = data['id'] as String?;
  final status = data['status'] as String?;
  if (id != null && id.isNotEmpty && kPickUpStartableStatuses.contains(status)) {
    final resp = await ipc.request(
      'pql.tickets.status',
      args: {
        'ids': [id],
        'status': 'in_progress',
      },
    );
    if (resp.ok) messages.publish('builtin.tickets', 'changed', {'id': id});
  }
  return true;
}
