/// Owns the set of clide-managed Claude sessions (T-169, D-77).
///
/// A session is a `claude` stream-json process clide spawns and renders; a
/// pane is just a *view* on one. The orchestrator decouples a session's
/// lifecycle from any pane: [spawn] starts and registers it, [show]/[hide]
/// toggle visibility WITHOUT tearing the process down, and [close] kills it.
/// This is the one primitive behind teammate / secondary tab / forked branch
/// (Phase 2): they are all just managed sessions shown as panes.
///
/// The process factory is injectable so tests drive the lifecycle without
/// spawning a real `claude`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/claude/src/team_broker.dart';
import 'package:clide/builtin/claude/src/team_chat_model.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:flutter/foundation.dart';

/// Max bytes of recent transcript to replay into the [ConversationController]
/// when resuming a session — `claude --resume` carries Claude's context but
/// emits no past turns over stream-json, so the pane would start empty
/// without this hydration. Matches [TranscriptReader]'s initial-tail size.
const _resumeTailBytes = 256 * 1024;

/// Creates the subprocess for a session — production uses
/// [ClaudeStreamJsonProcess.start]; tests inject a fake.
typedef ProcessFactory = Future<StreamJsonProcess> Function({
  required List<String> sessionArgs,
  required String cwd,
  Map<String, String>? env,
});

/// What to spawn. [id] is the orchestrator's stable key (e.g. `primary`,
/// `teammate:tyre`); [sessionId] is claude's `--session-id`.
class SpawnSpec {
  const SpawnSpec({
    required this.id,
    required this.role,
    required this.sessionId,
    required this.cwd,
    this.resume = false,
    this.transcriptPath,
    this.env,
    this.visible = true,
    this.team = false,
    this.memberName,
    this.forkSourceSessionId,
  });

  final String id;
  final String role;
  final String sessionId;
  final String cwd;

  /// Resume an existing session (`--resume`) vs create one (`--session-id`).
  final bool resume;

  /// Transcript JSONL to replay into the conversation when [resume] is true.
  /// Optional — without it, a resumed session still works but its pane starts
  /// empty until the user sends a new prompt.
  final String? transcriptPath;
  final Map<String, String>? env;
  final bool visible;

  /// Join the team broker: host the `clide-team` MCP server and inject
  /// team-awareness into the system prompt (T-170). Solo sessions leave this
  /// false and behave exactly as before.
  final bool team;

  /// Name teammates address this session by (`send_message(to: …)`); defaults
  /// to [role] when omitted. Only meaningful when [team] is true.
  final String? memberName;

  /// When non-null, spawn a forked branch of this claude session id (T-172).
  /// Uses `--resume <forkSourceSessionId> --fork-session` so the branch
  /// diverges into a NEW claude session without touching the original.
  /// Takes precedence over [resume]/[sessionId] for arg selection.
  final String? forkSourceSessionId;

  /// Whether this spec spawns a forked session.
  bool get isFork => forkSourceSessionId != null;
}

/// One clide-managed session: the process wrapper plus the conversation it
/// feeds. Owned by the orchestrator, not by any pane — so hiding a pane
/// leaves it (and its accumulating conversation) intact.
class ManagedSession {
  ManagedSession({
    required this.id,
    required this.role,
    required this.sessionId,
    required this.cwd,
    required this.session,
    required this.conversation,
    this.memberName,
    this.visible = true,
    this.muted = false,
    this.forkSourceSessionId,
  });

  final String id;
  final String role;

  /// The clide-internal session id. For fork sessions this is the placeholder
  /// UUID passed via [SpawnSpec.sessionId]; the real claude-assigned session id
  /// arrives in the `init` event and is not yet captured here (T-172 follow-up).
  final String sessionId;

  /// The working directory this session was spawned in. Retained so forks and
  /// the UI can reference the source context (T-172).
  final String cwd;

  final StreamJsonSession session;
  final ConversationController conversation;

  /// Team-member display name (from [SpawnSpec.memberName]); used to resolve a
  /// roster row back to its session. Null for non-team sessions.
  final String? memberName;

  /// Whether a pane is currently showing this session. A view toggle only —
  /// the process stays alive when hidden.
  bool visible;

  /// Whether message delivery from the broker to this session is suppressed.
  /// The session process still runs; teammates' messages accumulate in its
  /// inbox but are not injected into stdin until unmuted (T-171).
  bool muted;

  /// The source claude session id this was forked from (T-172), or null for
  /// non-fork sessions. For display / provenance only.
  final String? forkSourceSessionId;

  /// Whether this is a forked session.
  bool get isFork => forkSourceSessionId != null;
}

/// App-wide orchestrator, set by the Claude extension on activate (like
/// `activeClaudeConfig`). Panes spawn/bind their session through it so the
/// session set is shared across panes, the cockpit, and team tiles.
ClaudeSessionOrchestrator? activeSessionOrchestrator;

class ClaudeSessionOrchestrator extends ChangeNotifier {
  ClaudeSessionOrchestrator({ProcessFactory? processFactory}) : _factory = processFactory ?? _spawnClaude {
    _chatModel = TeamChatModel(
      broker: broker,
      sessionResolver: (name) => byMemberName(name)?.session,
    );
  }

  final ProcessFactory _factory;
  final _sessions = <String, ManagedSession>{};

  /// The shared team coordination state. Team sessions host an MCP server that
  /// routes through this; a `send_message` is delivered into the target
  /// session's next turn (T-170).
  late final TeamBroker broker = TeamBroker(deliver: _deliverToSession);

  /// The shared chat timeline and user-post logic (T-180). Both the compact
  /// sidebar widget and the full workspace pane read from this model.
  late final TeamChatModel _chatModel;

  /// Exposes the shared chat model to widgets and panes.
  TeamChatModel get chatModel => _chatModel;

  void _deliverToSession(String toId, String text) => _sessions[toId]?.session.send(text);

  static Future<StreamJsonProcess> _spawnClaude({required List<String> sessionArgs, required String cwd, Map<String, String>? env}) =>
      ClaudeStreamJsonProcess.start(sessionArgs: sessionArgs, cwd: cwd, env: env);

  /// All managed sessions, in insertion order.
  List<ManagedSession> get sessions => List.unmodifiable(_sessions.values);

  /// Just the sessions a pane should currently render.
  List<ManagedSession> get visibleSessions => [
        for (final m in _sessions.values)
          if (m.visible) m,
      ];

  ManagedSession? byId(String id) => _sessions[id];

  /// Spawn and register a session. Idempotent on [SpawnSpec.id] — a repeat
  /// call returns the existing session rather than starting a second process.
  Future<ManagedSession> spawn(SpawnSpec spec) async {
    final existing = _sessions[spec.id];
    if (existing != null) return existing;

    // Team sessions host the clide-team MCP server and get a roster + role
    // injected into their system prompt (T-170). Register the member before
    // spawning so a peer that messages it immediately resolves.
    final mcpServers = <McpServer>[];
    // Fork sessions use --resume <source> --fork-session so the branch gets its
    // own claude session id from the init event (T-172). All other sessions use
    // the normal --resume / --session-id selection.
    var sessionArgs = spec.isFork ? forkSessionArgs(spec.forkSourceSessionId!) : claudeLaunchArgs(spec.sessionId, resume: spec.resume);
    if (spec.team) {
      final name = spec.memberName ?? spec.role;
      broker.addMember(TeamMemberRef(id: spec.id, name: name, role: spec.role));
      mcpServers.add(TeamMcpServer(broker: broker, memberId: spec.id));
      sessionArgs = ['--append-system-prompt', _teamSystemPrompt(name, spec.role), ...sessionArgs];
    }

    final proc = await _factory(
      sessionArgs: sessionArgs,
      cwd: spec.cwd,
      env: spec.env,
    );
    final session = StreamJsonSession(proc, mcpServers: mcpServers)..start();
    final seed = spec.resume && spec.transcriptPath != null ? await _readTranscriptTail(spec.transcriptPath!) : null;
    final conversation = ConversationController(stream: session.items, seed: seed, onDispose: session.dispose);
    final managed = ManagedSession(
      id: spec.id,
      role: spec.role,
      sessionId: spec.sessionId,
      cwd: spec.cwd,
      session: session,
      conversation: conversation,
      memberName: spec.memberName,
      visible: spec.visible,
      forkSourceSessionId: spec.forkSourceSessionId,
    );
    _sessions[spec.id] = managed;
    notifyListeners();
    return managed;
  }

  // --- member name → session bridge (T-171) ----------------------------------

  /// Resolve a roster row to its [ManagedSession] by team-member name. Team
  /// sessions are keyed `teammate:<name>`, so that direct hit covers the common
  /// case; the fallback scans [ManagedSession.memberName] for sessions whose id
  /// scheme differs. The sidebar passes the member's display name (which the
  /// orchestrator also stored at spawn), so the link is deterministic.
  ManagedSession? byMemberName(String name) {
    final direct = _sessions['teammate:$name'];
    if (direct != null) return direct;
    for (final m in _sessions.values) {
      if (m.memberName == name) return m;
    }
    return null;
  }

  // --- Show / hide ----------------------------------------------------------

  /// Show / hide a session as a pane — a visibility toggle only; the process
  /// keeps running while hidden.
  void show(String id) => _setVisible(id, true);
  void hide(String id) => _setVisible(id, false);

  void _setVisible(String id, bool value) {
    final m = _sessions[id];
    if (m == null || m.visible == value) return;
    m.visible = value;
    notifyListeners();
  }

  /// Kill and forget a session (the real teardown). The conversation's
  /// onDispose kills the process + closes its streams.
  Future<void> close(String id) async {
    final m = _sessions.remove(id);
    if (m == null) return;
    broker.removeMember(id);
    m.conversation.dispose();
    notifyListeners();
  }

  // --- Mute / unmute (T-171) ------------------------------------------------

  /// Mute an agent: suppresses broker delivery into the session's stdin while
  /// the process continues running.  Syncs the [ManagedSession.muted] flag and
  /// gates delivery in the broker.
  void mute(String id) {
    final m = _sessions[id];
    if (m == null || m.muted) return;
    m.muted = true;
    broker.mute(id);
    notifyListeners();
  }

  /// Unmute an agent: re-enables broker delivery into the session's stdin.
  void unmute(String id) {
    final m = _sessions[id];
    if (m == null || !m.muted) return;
    m.muted = false;
    broker.unmute(id);
    notifyListeners();
  }

  // --- Inject message (T-171) -----------------------------------------------

  /// Inject [text] directly into [id]'s session stdin as a user-role turn.
  /// Thin wrapper over [StreamJsonSession.send] so callers (sidebar, tests)
  /// don't depend on the session type.  No-op if the session is unknown.
  void injectMessage(String id, String text) {
    _sessions[id]?.session.send(text);
  }

  /// Read up to [_resumeTailBytes] from the end of [path] and parse it into
  /// items to seed the conversation. Best-effort: a missing/unreadable file
  /// returns null and the pane resumes empty, same as before this fix.
  Future<List<ConversationItem>?> _readTranscriptTail(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      final length = await f.length();
      final start = length > _resumeTailBytes ? length - _resumeTailBytes : 0;
      final raf = await f.open();
      try {
        await raf.setPosition(start);
        final bytes = await raf.read(length - start);
        final text = utf8.decode(bytes, allowMalformed: true);
        // Started mid-file → drop the partial first line so we never feed
        // half a JSON record to the parser.
        final chunk = start == 0 ? text : text.substring(text.indexOf('\n') + 1);
        return parseTranscriptChunk(chunk).items;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// The team-awareness preamble injected via `--append-system-prompt` (T-170).
  static String _teamSystemPrompt(String name, String role) => 'You are part of a clide-managed agent team. Your name is "$name" and your role is "$role". '
      'Coordinate with teammates using the clide-team MCP tools: '
      'send_message(to, text) to message one teammate by name, broadcast(text) to message all, '
      'list_teammates() to see the roster, inbox() to read messages sent to you, and '
      'claim_task/task_status for the shared task list. '
      'Messages from teammates arrive in your conversation prefixed with "[team]".';

  @override
  void dispose() {
    for (final m in _sessions.values) {
      m.conversation.dispose();
    }
    _sessions.clear();
    _chatModel.dispose();
    broker.dispose();
    super.dispose();
  }
}
