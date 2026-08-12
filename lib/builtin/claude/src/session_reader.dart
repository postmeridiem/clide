/// One place that knows how to read a Claude session (T-551, epic T-550).
///
/// Three call sites had each written this by hand — `claude_pane.dart`,
/// `claude_meta_sidebar.dart`'s `_bindPrimary`, and the companion's
/// `load_adapter.dart`, the last produced by copying the second — and Epic D
/// wanted a fourth. Four copies of a rule nobody wrote down is the maintenance
/// surface this removes.
///
/// **A consumer subscribes once and never sees the orchestrator.** Sessions come
/// and go — a respawn after `/clear`, a workspace switch, an account change —
/// and the streams below survive all of it, because the reader re-subscribes
/// underneath rather than making every caller re-bind.
///
/// ## Session-agnostic, deliberately
///
/// It reads *a* session id, not "the primary one". All three existing consumers
/// read the primary, so an interface that assumed it would pass every migration
/// and then fail the moment Epic D bound the companion — this epic's own bug,
/// one layer up. [SessionReader.primary] is a convenience over the general case,
/// not the other way round.
///
/// ## What the three copies disagreed about, and what that settled
///
/// * **Absence.** The pane spawns a session, the sidebar clears its state, the
///   adapter publishes a defined "nothing is running". Three answers, all right
///   for their surface — so the reader **reports** absence ([attached]) and
///   never decides what it means.
/// * **Seeding.** The pane seeds `end` by hand because `endedStream` does not
///   replay; the sidebar seeds `status` by hand even though `statusStream` does;
///   the adapter seeds nothing and relies on replay. The reader seeds the ones
///   that need it, so no caller has to know which is which.
/// * **Rebinding.** The sidebar and the adapter re-bind on orchestrator
///   notifications; the pane does not. Rebinding is the correct behaviour and is
///   built in.
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/builtin/claude/src/turn_signals.dart';
import 'package:clide/builtin/claude/src/workflow_run.dart';
import 'package:clide/src/util/value_stream.dart';
import 'package:flutter/foundation.dart';

/// The orchestrator id of the primary session — the one the Claude pane hosts.
const kPrimarySessionId = 'primary';

/// Follows one managed session and forwards everything it reports.
///
/// A `ChangeNotifier` for the binding itself (bound / unbound / swapped), plus a
/// stream per signal. Notification and streams are separate on purpose: a widget
/// usually wants to rebuild when the session *changes*, and rarely wants to
/// rebuild on every token.
class SessionReader extends ChangeNotifier {
  SessionReader({required this.sessionId, ClaudeSessionOrchestrator? orchestrator}) : _explicit = orchestrator;

  /// Convenience for the common case. Not a different mechanism.
  SessionReader.primary({ClaudeSessionOrchestrator? orchestrator}) : this(sessionId: kPrimarySessionId, orchestrator: orchestrator);

  /// The orchestrator id to follow — `primary`, `clide.companion`, a teammate.
  final String sessionId;

  final ClaudeSessionOrchestrator? _explicit;

  ClaudeSessionOrchestrator? _orchestrator;
  ManagedSession? _managed;
  bool _started = false;
  bool _disposed = false;

  final _subs = <StreamSubscription<Object?>>[];

  // Replay-latest, because they carry state a late subscriber needs now.
  final _busy = ValueStream<bool>.seeded(false);
  final _status = ValueStream<SessionStatus>();
  final _phase = ValueStream<TurnPhase>.seeded(TurnPhase.idle);
  final _workflows = ValueStream<Map<String, WorkflowRun>>.seeded(const {});
  final _pending = ValueStream<ToolPrompt?>.seeded(null);

  // Events, not state: a subscriber that missed one has missed it.
  final _items = StreamController<ConversationItem>.broadcast();
  final _ended = StreamController<SessionEnd>.broadcast();
  final _modelErrors = StreamController<String>.broadcast();
  final _outcomes = StreamController<TurnOutcome>.broadcast();
  final _usage = StreamController<TurnUsage>.broadcast();

  /// Whether a session is currently bound.
  ///
  /// The reader reports this and draws no conclusion from it — absence means
  /// "spawn one" to the pane, "clear the panel" to the sidebar and "publish
  /// not-busy" to the companion adapter, and those are all correct.
  bool get attached => _managed != null;

  /// The bound session, or null. Prefer the streams; this is for the cases that
  /// genuinely need the object — sending a prompt, reading `conversation`.
  ManagedSession? get managed => _managed;

  StreamJsonSession? get session => _managed?.session;

  Stream<bool> get busy => _busy.stream;
  Stream<SessionStatus> get status => _status.stream;
  Stream<TurnPhase> get phase => _phase.stream;
  Stream<Map<String, WorkflowRun>> get workflows => _workflows.stream;
  Stream<ToolPrompt?> get pendingPrompt => _pending.stream;
  Stream<ConversationItem> get items => _items.stream;
  Stream<SessionEnd> get ended => _ended.stream;
  Stream<String> get modelErrors => _modelErrors.stream;
  Stream<TurnOutcome> get turnOutcomes => _outcomes.stream;

  /// What each turn spent, as a per-turn delta (T-556).
  ///
  /// Survives a session being replaced underneath, which is the whole reason a
  /// ledger can be built on it: the companion restarts on `/clear`, a locale
  /// change or an edited brief, and a total that reset with the process would
  /// answer a question nobody asked.
  Stream<TurnUsage> get turnUsage => _usage.stream;

  /// Latest busy state without subscribing.
  bool get isBusy => _busy.value;

  /// When the bound session's current turn began, or null when idle (T-561).
  ///
  /// Read through rather than cached: the session owns the fact, and a copy
  /// here would be one more thing to keep in step across a rebind.
  DateTime? get busySince => _managed?.session.busySince;

  /// Begin following. Idempotent.
  ///
  /// [orchestrator] overrides the one given to the constructor, for callers that
  /// only learn it later. Passing null falls back to the global
  /// [activeSessionOrchestrator], which is how the app wires it and how tests
  /// inject a fake.
  void start([ClaudeSessionOrchestrator? orchestrator]) {
    if (_disposed) return;
    final next = orchestrator ?? _explicit ?? activeSessionOrchestrator;
    if (_started && identical(next, _orchestrator)) return;

    _orchestrator?.removeListener(_onOrchestratorChanged);
    _orchestrator = next;
    _orchestrator?.addListener(_onOrchestratorChanged);
    _started = true;
    _bind();
  }

  void _onOrchestratorChanged() => _bind();

  /// (Re)bind to whatever currently answers to [sessionId].
  ///
  /// Runs often — the orchestrator notifies on spawn, close, show, hide, mute
  /// and session-id resolution, all routine — so it must be cheap and it must be
  /// idempotent. **Cancelling first is not optional:** a missed cancel leaves the
  /// old subscriptions live and every later event is handled twice.
  void _bind() {
    if (_disposed) return;
    final next = _orchestrator?.byId(sessionId);
    final changed = !identical(next, _managed);

    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _managed = next;

    final session = next?.session;
    if (session == null) {
      // Absence is a state, not an error, and it is reported rather than
      // interpreted. The busy signal drops so nothing is left believing a
      // vanished session is still working.
      _busy.add(false);
      _phase.add(TurnPhase.idle);
      if (changed) notifyListeners();
      return;
    }

    // Replay-latest sources need no seeding — subscribing is the seed.
    _subs
      ..add(session.busyStream.listen(_busy.add))
      ..add(session.statusStream.listen(_status.add))
      ..add(session.phaseStream.listen(_phase.add))
      ..add(session.workflowsStream.listen(_workflows.add))
      ..add(session.pendingPromptStream.listen(_pending.add))
      ..add(session.items.listen(_forward(_items)))
      ..add(session.modelErrors.listen(_forward(_modelErrors)))
      ..add(session.turnOutcomes.listen(_forward(_outcomes)))
      ..add(session.turnUsage.listen(_forward(_usage)));

    // `endedStream` does NOT replay, so a reader binding after the process died
    // would otherwise wait forever for news that already came and gone — the
    // session would look thoughtful rather than dead (T-361). The pane is the
    // only existing consumer that got this right; here nobody has to know.
    final already = session.end;
    if (already != null) {
      _forward(_ended)(already);
    } else {
      _subs.add(session.endedStream.listen(_forward(_ended)));
    }

    if (changed) notifyListeners();
  }

  /// Forward into an outer controller, ignoring anything that arrives after
  /// disposal — an inner stream can outlive a cancel by a microtask.
  void Function(T) _forward<T>(StreamController<T> out) => (T value) {
    if (!_disposed && !out.isClosed) out.add(value);
  };

  @override
  void dispose() {
    _disposed = true;
    _orchestrator?.removeListener(_onOrchestratorChanged);
    _orchestrator = null;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _managed = null;
    // The ValueStreams are closed too — a consumer holding one after dispose
    // gets a done, not a stream that quietly never fires again.
    _busy.close();
    _status.close();
    _phase.close();
    _workflows.close();
    _pending.close();
    _items.close();
    _ended.close();
    _modelErrors.close();
    _outcomes.close();
    _usage.close();
    super.dispose();
  }
}
