/// Team coordination broker hosted in clide and exposed to managed Claude
/// sessions as an in-process MCP server (T-170, D-77).
///
/// Claude's tmux team mode gave teammates ways to talk to each other and share
/// a task list. That mode is undocumented and unavailable headless, so clide
/// rebuilds the same behavior over its own managed sessions: clide is the
/// BROKER. Each agent gets an [McpServer] (`clide-team`) whose tools route
/// through this one shared [TeamBroker] — a `send_message` from agent A is
/// delivered into agent B's next turn on B's stdin, and the task list is shared
/// across everyone. clide owns routing and ordering.
///
/// Flutter-free on purpose: this and [TeamMcpServer] run under `dart test`, and
/// the transport ([McpServer], [StreamJsonSession]) is Flutter-free too.
library;

import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/claude/src/stream_json_session.dart';

/// One agent in the team, keyed by its orchestrator session id.
class TeamMemberRef {
  const TeamMemberRef({required this.id, required this.name, required this.role});

  /// Orchestrator session id (the [McpServer] is scoped to this), e.g.
  /// `primary` or `teammate:tyre`.
  final String id;

  /// Display name other members address it by (`send_message(to: …)`).
  final String name;

  /// `lead` / `teammate` / etc. — surfaced in `list_teammates`.
  final String role;
}

/// A message left for a member, in arrival order.
class TeamMessage {
  const TeamMessage({
    required this.from,
    required this.text,
    required this.at,
    this.to,
    this.broadcast = false,
  });
  final String from;

  /// Recipient name: a single member's display name (direct message), `null`
  /// for a broadcast (every member), or the special value `'user'` when the
  /// broker surfaces the message to the chat model rather than a session.
  final String? to;
  final String text;
  final DateTime at;
  final bool broadcast;

  Map<String, dynamic> toJson() => {
        'from': from,
        if (to != null) 'to': to,
        'text': text,
        'at': at.toIso8601String(),
        if (broadcast) 'broadcast': true,
      };
}

/// A shared task. Status is one of `open` / `claimed` / `done`.
class TeamTask {
  TeamTask({required this.id, required this.title, this.status = 'open', this.owner});
  final String id;
  String title;
  String status;
  String? owner;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status,
        if (owner != null) 'owner': owner,
      };
}

/// Pushes [text] into the member identified by [toMemberId] as a user message
/// on its session stdin. Injected by the orchestrator; null in tests that only
/// assert the broker's bookkeeping.
typedef MessageDelivery = void Function(String toMemberId, String text);

/// The single shared team state behind every member's `clide-team` MCP server.
/// All tool operations are scoped to the calling member's id.
///
/// Observability (T-171): subscribe to [changes] to be notified whenever the
/// task list or message state mutates. Flutter-free — the stream is a plain
/// broadcast [StreamController]; consumers must not assume it fires on the
/// Flutter event loop.
class TeamBroker {
  TeamBroker({MessageDelivery? deliver}) : _deliver = deliver {
    // The user is always a virtual team participant — agents can address them
    // by name; messages routed to `user` surface in the chat model only (no
    // stdin delivery). Registered at construction so the roster is consistent.
    addMember(const TeamMemberRef(id: 'user', name: 'user', role: 'user'));
  }

  final MessageDelivery? _deliver;
  final _members = <String, TeamMemberRef>{};
  final _inboxes = <String, List<TeamMessage>>{};
  final _tasks = <String, TeamTask>{};
  final _muted = <String>{}; // member ids whose delivery is gated
  int _taskSeq = 0;

  // --- Observability ---------------------------------------------------------

  final _changeCtl = StreamController<void>.broadcast();
  final _messageCtl = StreamController<TeamMessage>.broadcast();

  /// Fires a void event whenever the task list or message state mutates.
  /// Broadcast — multiple listeners are supported.  Flutter-free.
  Stream<void> get changes => _changeCtl.stream;

  /// Every inter-agent message (send_message / broadcast) in arrival order.
  /// Also includes messages directed `to: 'user'` so the chat model can surface
  /// them. Broadcast — multiple listeners are supported. Flutter-free.
  Stream<TeamMessage> get messages => _messageCtl.stream;

  void _notify() {
    if (!_changeCtl.isClosed) _changeCtl.add(null);
  }

  // --- Public read surface ---------------------------------------------------

  /// All tasks in creation order. Unmodifiable list; individual [TeamTask]
  /// objects may be mutated but the list itself is stable.
  List<TeamTask> get tasks => List.unmodifiable(_tasks.values);

  /// Register a member. Idempotent on [TeamMemberRef.id].
  void addMember(TeamMemberRef m) {
    _members[m.id] = m;
    _inboxes.putIfAbsent(m.id, () => <TeamMessage>[]);
  }

  /// Drop a member (its inbox is discarded; tasks it owned are released).
  void removeMember(String id) {
    final name = _members[id]?.name;
    _members.remove(id);
    _inboxes.remove(id);
    _muted.remove(id);
    if (name == null) return;
    for (final t in _tasks.values) {
      if (t.owner == name) {
        t.owner = null;
        if (t.status == 'claimed') t.status = 'open';
      }
    }
    _notify();
  }

  // --- Mute / unmute --------------------------------------------------------

  /// Whether delivery to [id] is currently muted. Muted members still
  /// accumulate inbox messages but the [MessageDelivery] callback is
  /// suppressed so the live session doesn't receive the text turn.
  bool isMuted(String id) => _muted.contains(id);

  /// Mute delivery to [id]. Messages still enqueue in the inbox; the agent
  /// just won't receive them in its live stdin until [unmute] is called.
  void mute(String id) {
    _muted.add(id);
  }

  /// Re-enable delivery to [id].
  void unmute(String id) {
    _muted.remove(id);
  }

  // --- Task management (user-facing) ----------------------------------------

  /// Reassign task [taskId] to the member identified by [toMemberId] (may be
  /// a member id like `teammate:tyre`). Updates the owner display-name from
  /// the member roster and fires [changes]. Returns false if [taskId] is
  /// unknown.
  bool reassignTask(String taskId, String toMemberId) {
    final t = _tasks[taskId];
    if (t == null) return false;
    final name = _members[toMemberId]?.name ?? toMemberId;
    t.owner = name;
    if (t.status == 'open') t.status = 'claimed';
    _notify();
    return true;
  }

  /// Dispose — closes the [changes] and [messages] stream controllers.
  void dispose() {
    _changeCtl.close();
    _messageCtl.close();
  }

  /// All members in registration order.
  List<TeamMemberRef> get members => List.unmodifiable(_members.values);

  TeamMemberRef? _byName(String name) {
    final lower = name.toLowerCase();
    for (final m in _members.values) {
      if (m.name.toLowerCase() == lower) return m;
    }
    return null;
  }

  String _nameOf(String id) => _members[id]?.name ?? id;

  // --- Tool operations (scoped to the caller [fromId]) ---------------------

  /// Post [text] from the human user into the channel. When [to] is null or
  /// omitted the message is broadcast; otherwise it is delivered only to the
  /// named member. The `user` member is the caller's virtual id — it is
  /// excluded from the recipient list in the same way senders are excluded
  /// from their own broadcasts.
  void sendAsUser(String text, {String? to}) {
    if (to == null || to.isEmpty || to == 'team') {
      // Broadcast: deliver to every non-user member.
      // emitToStream=false: the chat model already recorded the local entry.
      for (final m in _members.values) {
        if (m.id == 'user') continue;
        _enqueue(m.id, TeamMessage(from: 'user', to: null, text: text, at: DateTime.now(), broadcast: true), broadcast: true, emitToStream: false);
      }
    } else {
      // Directed: deliver to the named member.
      final target = _byName(to);
      if (target == null || target.id == 'user') return;
      _enqueue(target.id, TeamMessage(from: 'user', to: target.name, text: text, at: DateTime.now()), emitToStream: false);
    }
  }

  /// Deliver [text] to the single member named [toName].
  Map<String, dynamic> sendMessage(String fromId, String toName, String text) {
    final target = _byName(toName);
    if (target == null) {
      return {'ok': false, 'error': 'No teammate named "$toName". Use list_teammates to see who is on the team.'};
    }
    _enqueue(target.id, TeamMessage(from: _nameOf(fromId), to: target.name, text: text, at: DateTime.now()));
    return {'ok': true, 'to': target.name};
  }

  /// Deliver [text] to every member except the sender.
  Map<String, dynamic> broadcast(String fromId, String text) {
    final fromName = _nameOf(fromId);
    final recipients = <String>[];
    for (final m in _members.values) {
      if (m.id == fromId) continue;
      _enqueue(m.id, TeamMessage(from: fromName, to: null, text: text, at: DateTime.now(), broadcast: true), broadcast: true);
      recipients.add(m.name);
    }
    return {'ok': true, 'recipients': recipients};
  }

  /// The team roster as seen by [fromId] (everyone else).
  Map<String, dynamic> listTeammates(String fromId) {
    final others = [
      for (final m in _members.values)
        if (m.id != fromId) {'name': m.name, 'role': m.role},
    ];
    return {'teammates': others};
  }

  /// Return and clear the caller's pending messages.
  Map<String, dynamic> inbox(String fromId) {
    final box = _inboxes[fromId] ?? const <TeamMessage>[];
    final out = [for (final m in box) m.toJson()];
    _inboxes[fromId]?.clear();
    return {'messages': out};
  }

  /// Claim an existing task by [id], or create one from [title] already claimed
  /// by the caller. Returns the task.
  Map<String, dynamic> claimTask(String fromId, {String? id, String? title}) {
    final owner = _nameOf(fromId);
    if (id != null && id.isNotEmpty) {
      final t = _tasks[id];
      if (t == null) return {'ok': false, 'error': 'No task "$id".'};
      t.owner = owner;
      t.status = 'claimed';
      _notify();
      return {'ok': true, 'task': t.toJson()};
    }
    if (title != null && title.trim().isNotEmpty) {
      final t = TeamTask(id: 'task-${++_taskSeq}', title: title.trim(), status: 'claimed', owner: owner);
      _tasks[t.id] = t;
      _notify();
      return {'ok': true, 'task': t.toJson()};
    }
    return {'ok': false, 'error': 'Pass a task id to claim, or a title to create one.'};
  }

  /// Update a task's [status] (and implicitly own it), or — with no [id] — list
  /// every task. Creating a new open task is done with [title].
  Map<String, dynamic> taskStatus(String fromId, {String? id, String? status, String? title}) {
    if (title != null && title.trim().isNotEmpty && (id == null || id.isEmpty)) {
      final t = TeamTask(id: 'task-${++_taskSeq}', title: title.trim());
      _tasks[t.id] = t;
      _notify();
      return {'ok': true, 'task': t.toJson()};
    }
    if (id != null && id.isNotEmpty && status != null && status.isNotEmpty) {
      final t = _tasks[id];
      if (t == null) return {'ok': false, 'error': 'No task "$id".'};
      t.status = status;
      if (status == 'claimed' || status == 'done') t.owner = _nameOf(fromId);
      _notify();
      return {'ok': true, 'task': t.toJson()};
    }
    return {
      'tasks': [for (final t in _tasks.values) t.toJson()]
    };
  }

  void _enqueue(String toId, TeamMessage msg, {bool broadcast = false, bool emitToStream = true}) {
    (_inboxes[toId] ??= <TeamMessage>[]).add(msg);
    // Emit every message to the chat model stream before (possibly) delivering
    // to the session stdin. The `user` member is a virtual participant — it has
    // no session stdin, so delivery is skipped for it.
    //
    // [emitToStream] is false for user-originated messages that [TeamChatModel]
    // already recorded locally — avoids double-adding them to the timeline.
    if (emitToStream && !_messageCtl.isClosed) _messageCtl.add(msg);
    if (toId == 'user') {
      // User member: surfaced in the chat model only, no stdin delivery.
      _notify();
      return;
    }
    final tag = broadcast ? '${msg.from} (broadcast)' : msg.from;
    // Gate delivery: muted members still accumulate inbox messages but the
    // live session callback is suppressed until unmuted (T-171).
    if (!_muted.contains(toId)) {
      _deliver?.call(toId, '[team] $tag: ${msg.text}');
    }
    _notify();
  }
}

/// The per-session `clide-team` MCP server: a thin adapter that forwards each
/// tool call to the shared [broker], scoped to this session's [memberId].
class TeamMcpServer implements McpServer {
  TeamMcpServer({required this.broker, required this.memberId, this.name = 'clide-team', this.version = '0.1.0'});

  final TeamBroker broker;
  final String memberId;
  @override
  final String name;
  @override
  final String version;

  @override
  List<Map<String, dynamic>> get tools => _toolDefs;

  @override
  Future<Map<String, dynamic>> callTool(String name, Map<String, dynamic> arguments) async {
    switch (name) {
      case 'send_message':
        return _result(broker.sendMessage(memberId, arguments['to'] as String? ?? '', arguments['text'] as String? ?? ''));
      case 'broadcast':
        return _result(broker.broadcast(memberId, arguments['text'] as String? ?? ''));
      case 'list_teammates':
        return _result(broker.listTeammates(memberId));
      case 'inbox':
        return _result(broker.inbox(memberId));
      case 'claim_task':
        return _result(broker.claimTask(memberId, id: arguments['id'] as String?, title: arguments['title'] as String?));
      case 'task_status':
        return _result(
            broker.taskStatus(memberId, id: arguments['id'] as String?, status: arguments['status'] as String?, title: arguments['title'] as String?));
      default:
        return _error('Unknown team tool: $name');
    }
  }

  Map<String, dynamic> _result(Map<String, dynamic> value) => {
        'content': [
          {'type': 'text', 'text': jsonEncode(value)},
        ],
        'isError': value['ok'] == false,
      };

  Map<String, dynamic> _error(String message) => {
        'content': [
          {'type': 'text', 'text': message},
        ],
        'isError': true,
      };
}

const _toolDefs = <Map<String, dynamic>>[
  {
    'name': 'send_message',
    'description': 'Send a direct message to one teammate by name. It is delivered into their next turn.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'to': {'type': 'string', 'description': 'Teammate name (see list_teammates).'},
        'text': {'type': 'string', 'description': 'Message body.'},
      },
      'required': ['to', 'text'],
      'additionalProperties': false,
    },
  },
  {
    'name': 'broadcast',
    'description': 'Send a message to every other teammate at once.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'text': {'type': 'string', 'description': 'Message body.'},
      },
      'required': ['text'],
      'additionalProperties': false,
    },
  },
  {
    'name': 'list_teammates',
    'description': 'List the other members of the team with their roles.',
    'inputSchema': {'type': 'object', 'properties': <String, dynamic>{}, 'additionalProperties': false},
  },
  {
    'name': 'inbox',
    'description': 'Read and clear your pending team messages.',
    'inputSchema': {'type': 'object', 'properties': <String, dynamic>{}, 'additionalProperties': false},
  },
  {
    'name': 'claim_task',
    'description': 'Claim a shared task by id, or create a new task (by title) already claimed by you.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Existing task id to claim.'},
        'title': {'type': 'string', 'description': 'Title for a new task to create and claim.'},
      },
      'additionalProperties': false,
    },
  },
  {
    'name': 'task_status',
    'description': 'List all shared tasks, update a task status (open/claimed/done) by id, or create a new open task by title.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Task id to update.'},
        'status': {'type': 'string', 'description': 'New status: open, claimed, or done.'},
        'title': {'type': 'string', 'description': 'Title for a new open task.'},
      },
      'additionalProperties': false,
    },
  },
];
