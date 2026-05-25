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

import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:flutter/foundation.dart';

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
    this.env,
    this.visible = true,
  });

  final String id;
  final String role;
  final String sessionId;
  final String cwd;

  /// Resume an existing session (`--resume`) vs create one (`--session-id`).
  final bool resume;
  final Map<String, String>? env;
  final bool visible;
}

/// One clide-managed session: the process wrapper plus the conversation it
/// feeds. Owned by the orchestrator, not by any pane — so hiding a pane
/// leaves it (and its accumulating conversation) intact.
class ManagedSession {
  ManagedSession({
    required this.id,
    required this.role,
    required this.sessionId,
    required this.session,
    required this.conversation,
    this.visible = true,
  });

  final String id;
  final String role;
  final String sessionId;
  final StreamJsonSession session;
  final ConversationController conversation;

  /// Whether a pane is currently showing this session. A view toggle only —
  /// the process stays alive when hidden.
  bool visible;
}

/// App-wide orchestrator, set by the Claude extension on activate (like
/// `activeClaudeConfig`). Panes spawn/bind their session through it so the
/// session set is shared across panes, the cockpit, and team tiles.
ClaudeSessionOrchestrator? activeSessionOrchestrator;

class ClaudeSessionOrchestrator extends ChangeNotifier {
  ClaudeSessionOrchestrator({ProcessFactory? processFactory}) : _factory = processFactory ?? _spawnClaude;

  final ProcessFactory _factory;
  final _sessions = <String, ManagedSession>{};

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

    final proc = await _factory(
      sessionArgs: claudeLaunchArgs(spec.sessionId, resume: spec.resume),
      cwd: spec.cwd,
      env: spec.env,
    );
    final session = StreamJsonSession(proc)..start();
    final conversation = ConversationController(stream: session.items, onDispose: session.dispose);
    final managed = ManagedSession(
      id: spec.id,
      role: spec.role,
      sessionId: spec.sessionId,
      session: session,
      conversation: conversation,
      visible: spec.visible,
    );
    _sessions[spec.id] = managed;
    notifyListeners();
    return managed;
  }

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
    m.conversation.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final m in _sessions.values) {
      m.conversation.dispose();
    }
    _sessions.clear();
    super.dispose();
  }
}
