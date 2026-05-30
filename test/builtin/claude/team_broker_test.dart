import 'dart:convert';

import 'package:clide/builtin/claude/src/team_broker.dart';
import 'package:test/test.dart';

/// Decode a [TeamMcpServer] tool result's single text block back into the
/// structured map the broker returned.
Map<String, dynamic> decode(Map<String, dynamic> mcpResult) {
  final text = ((mcpResult['content'] as List).single as Map)['text'] as String;
  return jsonDecode(text) as Map<String, dynamic>;
}

void main() {
  late TeamBroker broker;
  late List<(String, String)> delivered; // (toMemberId, text)
  late TeamMcpServer lead;
  late TeamMcpServer tyre;

  setUp(() {
    delivered = [];
    broker = TeamBroker(deliver: (to, text) => delivered.add((to, text)));
    broker.addMember(const TeamMemberRef(id: 'primary', name: 'lead', role: 'lead'));
    broker.addMember(const TeamMemberRef(id: 'teammate:tyre', name: 'tyre', role: 'teammate'));
    lead = TeamMcpServer(broker: broker, memberId: 'primary');
    tyre = TeamMcpServer(broker: broker, memberId: 'teammate:tyre');
  });

  test('send_message delivers into the named teammate next turn', () async {
    final r = decode(await lead.callTool('send_message', {'to': 'tyre', 'text': 'pick up T-9'}));
    expect(r['ok'], isTrue);
    expect(r['to'], 'tyre');
    expect(delivered, [('teammate:tyre', '[team] lead: pick up T-9')]);
  });

  test('addressing an unknown teammate fails with a helpful error', () async {
    final result = await lead.callTool('send_message', {'to': 'ghost', 'text': 'hi'});
    expect(result['isError'], isTrue);
    expect(decode(result)['ok'], isFalse);
    expect(delivered, isEmpty);
  });

  test('the recipient can read the message from its inbox', () async {
    await lead.callTool('send_message', {'to': 'tyre', 'text': 'hello'});
    final box = decode(await tyre.callTool('inbox', {}));
    final msgs = box['messages'] as List;
    expect(msgs.single['from'], 'lead');
    expect(msgs.single['text'], 'hello');
    // Draining: a second read is empty.
    expect((decode(await tyre.callTool('inbox', {}))['messages'] as List), isEmpty);
  });

  test('broadcast reaches every other member but not the sender', () async {
    broker.addMember(const TeamMemberRef(id: 'teammate:qatux', name: 'qatux', role: 'teammate'));
    final r = decode(await lead.callTool('broadcast', {'text': 'standup'}));
    expect((r['recipients'] as List).toSet(), {'tyre', 'qatux'});
    expect(delivered.map((d) => d.$1).toSet(), {'teammate:tyre', 'teammate:qatux'});
  });

  test('list_teammates returns the other members with roles', () async {
    final r = decode(await lead.callTool('list_teammates', {}));
    final mates = r['teammates'] as List;
    expect(mates.single, {'name': 'tyre', 'role': 'teammate'});
  });

  test('a claimed task is visible to every member as shared state', () async {
    final claimed = decode(await tyre.callTool('claim_task', {'title': 'wire the broker'}));
    final taskId = (claimed['task'] as Map)['id'] as String;
    expect((claimed['task'] as Map)['owner'], 'tyre');

    final seenByLead = decode(await lead.callTool('task_status', {}));
    final tasks = seenByLead['tasks'] as List;
    expect(tasks.single['id'], taskId);
    expect(tasks.single['status'], 'claimed');

    final done = decode(await lead.callTool('task_status', {'id': taskId, 'status': 'done'}));
    expect((done['task'] as Map)['status'], 'done');
  });

  test('removing a member releases its claimed tasks', () async {
    final claimed = decode(await tyre.callTool('claim_task', {'title': 'temp'}));
    final taskId = (claimed['task'] as Map)['id'] as String;
    broker.removeMember('teammate:tyre');
    final tasks = decode(await lead.callTool('task_status', {}))['tasks'] as List;
    final t = tasks.firstWhere((t) => t['id'] == taskId);
    expect(t['status'], 'open');
    expect(t.containsKey('owner'), isFalse);
  });

  test('claim_task by id claims an existing open task', () async {
    final created = decode(await lead.callTool('task_status', {'title': 'open work'}));
    final id = (created['task'] as Map)['id'] as String;
    expect((created['task'] as Map)['status'], 'open');

    final claimed = decode(await tyre.callTool('claim_task', {'id': id}));
    expect((claimed['task'] as Map)['status'], 'claimed');
    expect((claimed['task'] as Map)['owner'], 'tyre');
  });

  test('claim_task with neither id nor title is an error', () async {
    final r = await lead.callTool('claim_task', {});
    expect(r['isError'], isTrue);
  });

  test('claiming an unknown task id is an error', () async {
    final r = await lead.callTool('claim_task', {'id': 'task-999'});
    expect(r['isError'], isTrue);
  });

  test('task_status on an unknown id is an error', () async {
    final r = await lead.callTool('task_status', {'id': 'task-999', 'status': 'done'});
    expect(r['isError'], isTrue);
  });

  test('an unknown team tool is an error', () async {
    final r = await lead.callTool('nope', {});
    expect(r['isError'], isTrue);
  });

  test('removing an unknown member is a no-op', () {
    broker.removeMember('teammate:ghost');
    expect(broker.members.map((m) => m.name).toSet(), {'lead', 'tyre'});
  });

  test('the MCP tool surface lists all six team tools', () {
    final names = lead.tools.map((t) => t['name']).toSet();
    expect(names, {'send_message', 'broadcast', 'list_teammates', 'inbox', 'claim_task', 'task_status'});
  });

  // T-171 additions -----------------------------------------------------------

  group('changes stream (T-171)', () {
    test('fires when a message is enqueued', () async {
      final events = <void>[];
      final sub = broker.changes.listen((_) => events.add(null));
      await lead.callTool('send_message', {'to': 'tyre', 'text': 'ping'});
      await sub.cancel();
      expect(events, hasLength(1));
    });

    test('fires when a task is created via claim_task', () async {
      final events = <void>[];
      final sub = broker.changes.listen((_) => events.add(null));
      await tyre.callTool('claim_task', {'title': 'new task'});
      await sub.cancel();
      expect(events, hasLength(1));
    });

    test('fires when a task status is updated', () async {
      final created = decode(await tyre.callTool('claim_task', {'title': 'update me'}));
      final id = (created['task'] as Map)['id'] as String;
      final events = <void>[];
      final sub = broker.changes.listen((_) => events.add(null));
      await lead.callTool('task_status', {'id': id, 'status': 'done'});
      await sub.cancel();
      expect(events, hasLength(1));
    });

    test('fires when a member is removed', () async {
      final events = <void>[];
      final sub = broker.changes.listen((_) => events.add(null));
      broker.removeMember('teammate:tyre');
      await Future<void>.delayed(Duration.zero); // let the broadcast event deliver
      await sub.cancel();
      expect(events, hasLength(1));
    });

    test('stream is closed after dispose', () async {
      var done = false;
      broker.changes.listen(null, onDone: () => done = true);
      broker.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });
  });

  group('tasks getter (T-171)', () {
    test('returns all tasks in creation order', () async {
      await lead.callTool('claim_task', {'title': 'alpha'});
      await tyre.callTool('claim_task', {'title': 'beta'});
      final titles = broker.tasks.map((t) => t.title).toList();
      expect(titles, ['alpha', 'beta']);
    });

    test('returns an empty list when no tasks exist', () {
      expect(broker.tasks, isEmpty);
    });
  });

  group('reassignTask (T-171)', () {
    test('reassigns to a known member by id', () async {
      final created = decode(await tyre.callTool('claim_task', {'title': 'reassignable'}));
      final id = (created['task'] as Map)['id'] as String;
      final ok = broker.reassignTask(id, 'primary');
      expect(ok, isTrue);
      final t = broker.tasks.firstWhere((t) => t.id == id);
      expect(t.owner, 'lead'); // display name from roster
    });

    test('returns false for an unknown task id', () {
      expect(broker.reassignTask('task-999', 'primary'), isFalse);
    });

    test('sets status to claimed when task was open', () async {
      decode(await lead.callTool('task_status', {'title': 'open task'}));
      final id = broker.tasks.last.id;
      expect(broker.tasks.last.status, 'open');
      broker.reassignTask(id, 'teammate:tyre');
      expect(broker.tasks.last.status, 'claimed');
    });

    test('fires the changes stream', () async {
      final created = decode(await tyre.callTool('claim_task', {'title': 'fire-stream'}));
      final id = (created['task'] as Map)['id'] as String;
      final events = <void>[];
      final sub = broker.changes.listen((_) => events.add(null));
      broker.reassignTask(id, 'primary');
      await Future<void>.delayed(Duration.zero); // let the broadcast event deliver
      await sub.cancel();
      expect(events, hasLength(1));
    });
  });

  group('muted delivery gating (T-171)', () {
    test('muted member does not receive stdin delivery', () async {
      broker.mute('teammate:tyre');
      await lead.callTool('send_message', {'to': 'tyre', 'text': 'quiet'});
      expect(delivered, isEmpty);
    });

    test('muted member still receives the inbox message', () async {
      broker.mute('teammate:tyre');
      await lead.callTool('send_message', {'to': 'tyre', 'text': 'silent'});
      final box = decode(await tyre.callTool('inbox', {}));
      expect((box['messages'] as List).single['text'], 'silent');
    });

    test('unmuting re-enables delivery', () async {
      broker.mute('teammate:tyre');
      broker.unmute('teammate:tyre');
      await lead.callTool('send_message', {'to': 'tyre', 'text': 'back'});
      expect(delivered.single.$1, 'teammate:tyre');
    });

    test('isMuted reflects current state', () {
      expect(broker.isMuted('teammate:tyre'), isFalse);
      broker.mute('teammate:tyre');
      expect(broker.isMuted('teammate:tyre'), isTrue);
      broker.unmute('teammate:tyre');
      expect(broker.isMuted('teammate:tyre'), isFalse);
    });

    test('broadcast is also gated for muted members', () async {
      broker.mute('teammate:tyre');
      await lead.callTool('broadcast', {'text': 'all-hands'});
      // tyre is muted → not in delivered; if there are other members they appear
      expect(delivered.map((d) => d.$1), isNot(contains('teammate:tyre')));
    });
  });
}
