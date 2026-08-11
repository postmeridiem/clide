/// The companion's process lifecycle (T-545, D-107).
///
/// Standing a session up is the easy half. The substance here is making it go
/// away reliably, because this process spends the **same subscription quota**
/// that rate-limits the session the user is actually driving (D-107 commitment
/// 1) — a companion that outlives its off switch is the exact failure that
/// switch exists to prevent.
///
/// Separate from [companion_session.dart], which names the id and hands out
/// readers: reading a session and owning its process are different jobs with
/// different lifetimes, and every consumer wants the first without the second.
///
/// ## Desired state in, process out
///
/// The controller reads nothing. [CompanionSessionController.sync] is handed the
/// three facts that decide whether a process should exist — enabled, open,
/// workspace — and brings the world into line. Everything that can change those
/// facts already lives in the extension, and routing them through one call keeps
/// this class testable without a kernel and keeps the "who decides" question
/// answered in exactly one place.
///
/// ## The four causes, and why they differ
///
/// | Cause | Process | Ingest |
/// |---|---|---|
/// | kill switch off | **torn down** | stopped |
/// | strip minimised / closed | kept | **paused** |
/// | primary cleared or restarted | restarted with it | restarted |
/// | context growth | nothing — autocompact handles it | continuous |
///
/// The kill switch is the only thing that drops the process. Minimising pauses
/// [CompanionSessionController.ingesting] and leaves the session parked: quota is
/// spent per *request*, not per second, so an idle session costs nothing but
/// memory, and dropping it would make a five-second minimise throw away
/// everything Clide knew. That keeps "off is off" meaning exactly one thing.
///
/// **Tracking the primary is not politeness.** `/clear` on the main pane means
/// the user believes they threw that conversation away; a companion still
/// holding it is a surprise and a quiet privacy problem, and it breaks the "he
/// is watching *this* conversation" framing the whole surface rests on.
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_reader.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/clide_companion/src/companion_session.dart';
import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/builtin/clide_companion/src/prompt/companion_digest.dart';
import 'package:clide/builtin/clide_companion/src/prompt/digest_lines.dart';
import 'package:clide/builtin/clide_companion/src/prompt/companion_trigger.dart';
import 'package:flutter/foundation.dart';

/// The model the companion runs on.
///
/// Passed as `--model` at spawn, **not** as a `set_model` control request.
/// The request route is right for an agent session, whose user can change model
/// mid-session — but the CLI echoes it into the conversation as a local command,
/// which put a caveat block, a `/model` line and its stdout at the head of
/// Clide's context. Found by reading his transcript on the first live run.
/// Effort is deliberately left unset: `--effort` errors on Haiku 4.5.
const kCompanionModel = 'haiku';

/// Refusal handed to any tool the companion asks to use.
///
/// It spawns `visible: false`, so a permission prompt has no pane to appear in
/// and would leave the session waiting forever on an answer that cannot come.
/// Denying is therefore the *lifecycle* correct answer, not a policy one.
const kCompanionToolDenial = 'Clide has no pane, so there is nobody here to approve tool use. Answer from the conversation you have already been given.';

/// Owns the companion `claude` process: spawns it, tears it down, and keeps it
/// in step with the primary session.
class CompanionSessionController extends ChangeNotifier {
  CompanionSessionController({
    ClaudeSessionOrchestrator? orchestrator,
    String Function()? newSessionId,
    SessionReader? primary,
    CompanionFrequency Function()? frequency,
    DateTime Function()? now,
  }) : _explicit = orchestrator,
       _newSessionId = newSessionId ?? companionSessionId,
       _primary = primary ?? SessionReader.primary(orchestrator: orchestrator) {
    _primary
      ..addListener(_onPrimaryChanged)
      ..start(orchestrator);
    _seenPrimary = _primary.managed;
    _trigger = CompanionTrigger(frequency: frequency ?? () => _frequency, now: now);
    _digest = CompanionDigest(source: _primary, ingesting: () => _ingesting)..start();
    _digestSub = _digest.lines.listen(_onDigest);
    _busySub = _primary.busy.listen((busy) {
      if (busy) _trigger.turnStarted();
    });
  }

  /// What the developer sees of the conversation, and what he is asked about.
  ///
  /// Both live here rather than in the extension because they are bound to the
  /// *session's* lifetime: a companion that is torn down must stop being fed,
  /// and a digest outliving its session would queue prompts for nobody.
  late final CompanionTrigger _trigger;
  late final CompanionDigest _digest;
  StreamSubscription<DigestTurn>? _digestSub;
  StreamSubscription<bool>? _busySub;

  /// Frequency, as desired state. Defaults until the first [sync].
  CompanionFrequency _frequency = CompanionFrequency.notable;

  final ClaudeSessionOrchestrator? _explicit;
  final String Function() _newSessionId;
  final SessionReader _primary;

  ClaudeSessionOrchestrator? get _orchestrator => _explicit ?? activeSessionOrchestrator;

  ManagedSession? _managed;

  /// The brief the live session was launched with, so a changed one is
  /// detectable. Cleared with the session.
  String? _spawnedBrief;
  StreamSubscription<ToolPrompt?>? _prompts;
  ManagedSession? _seenPrimary;

  bool _enabled = false;
  bool _ingesting = false;
  String? _root;
  String? _brief;
  Object? _spawnError;

  /// No further process work — set by [shutdown]/[dispose]. Distinct from
  /// [_notifierDisposed] because teardown outlives the synchronous
  /// [ChangeNotifier.dispose] it may have been triggered by.
  bool _stopped = false;
  bool _notifierDisposed = false;

  /// The live companion session, or null when none is running.
  ManagedSession? get session => _managed;

  /// Whether a companion process currently exists.
  bool get running => _managed != null;

  /// Whether the companion should be fed what it sees.
  ///
  /// False while the strip is closed, and the session stays up: a minimised
  /// stretch is conversation Clide genuinely did not see, which is both the
  /// honest privacy story and the cheapest power rung. T-546 gates the digest
  /// on this; nothing here produces input.
  bool get ingesting => _ingesting;

  /// Why the last spawn failed, or null. A missing `claude` must leave the
  /// controller idle and re-tryable, not wedged.
  Object? get spawnError => _spawnError;

  /// Bring the process into line with the desired state.
  ///
  /// Safe to call on every settings notification — it compares before acting,
  /// so the common case (nothing relevant changed) does no work. Calls are
  /// serialized against each other; spawning is asynchronous and two overlapping
  /// syncs would otherwise race to own the same orchestrator id.
  ///
  /// [brief] is the composed system prompt (T-532). It is desired state like the
  /// rest: it is fixed at spawn, so **changing it restarts him** — which is what
  /// makes a language change, a rename, or an edited self-description take
  /// effect at all. A null brief means he cannot run; the caller has nothing to
  /// launch him with.
  Future<void> sync({
    required bool enabled,
    required bool open,
    required String? root,
    required String? brief,
    CompanionFrequency frequency = CompanionFrequency.notable,
  }) {
    _enabled = enabled;
    _root = root;
    _brief = brief;
    // Live, unlike the brief: the trigger reads it per event, so turning him
    // down takes effect on the next turn rather than on the next restart.
    _frequency = frequency;
    // Ingest stops with the kill switch too — off is off at every level, not
    // just the process one.
    _setIngesting(enabled && open);
    return _serialize(_apply);
  }

  /// Put a question to Clide directly (T-564).
  ///
  /// **Bypasses the trigger entirely.** T-547 exists to bound *unsolicited*
  /// spend — frequency, pacing, debounce — and none of that applies to something
  /// the developer asked for. Routing a question through it would mean a
  /// question silently dropped because he happened to remark forty seconds ago,
  /// which is the worst possible failure for the one interaction that is
  /// supposed to be reliable.
  ///
  /// Returns false when there is no session to ask, so a caller can say so
  /// rather than swallowing it.
  bool ask(String question) {
    final session = _managed?.session;
    final text = question.trim();
    if (session == null || text.isEmpty) return false;
    session.send(directQuestion(text));
    return true;
  }

  /// Drop the session and start a fresh one, keeping nothing.
  ///
  /// The teardown `/clear` reuses (T-156) and the one a primary respawn
  /// triggers. A no-op while the companion is not meant to be running — a
  /// disabled companion has nothing to clear.
  Future<void> restart() => _serialize(() async {
    await _teardown();
    await _apply();
  });

  /// Terminal: tear the process down and stop following anything.
  ///
  /// Prefer this over [dispose] wherever the caller can await — killing a
  /// process is asynchronous, and only this form does not return until it is
  /// actually dead.
  Future<void> shutdown() async {
    if (_stopped) return _work;
    _stopped = true;
    _primary.removeListener(_onPrimaryChanged);
    await _digestSub?.cancel();
    await _busySub?.cancel();
    _digest.dispose();
    _primary.dispose();
    await _serialize(_teardown);
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    super.dispose();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    super.dispose();
  }

  // -- internals -------------------------------------------------------------

  Future<void> _work = Future<void>.value();

  /// Run [action] after every previously queued one. A failure is contained so
  /// one bad spawn cannot poison the queue for everything after it.
  Future<void> _serialize(Future<void> Function() action) {
    final next = _work.then((_) => action()).catchError((Object e) {
      _spawnError = e;
    });
    _work = next;
    return next;
  }

  Future<void> _apply() async {
    if (_stopped) return;
    final root = _root;
    final brief = _brief;
    // No brief is not an error state to surface — it is a packaging gap, and a
    // companion launched without one would be a stock assistant commenting on
    // the conversation. Better absent than wrong.
    if (!_enabled || root == null || brief == null || brief.trim().isEmpty) return _teardown();

    final existing = _managed;
    // A workspace switch in place means the running companion belongs to the
    // old repo. The orchestrator would respawn it for us on the cwd change, but
    // tearing down here keeps the session id fresh rather than reusing the one
    // minted for the previous repo.
    //
    // A changed brief is the other reason to replace a live session: the prompt
    // is argv, so there is no way to apply it to a running process.
    if (existing != null && existing.cwd == root && brief == _spawnedBrief) return;
    if (existing != null) await _teardown();

    final orch = _orchestrator;
    if (orch == null) return;

    _spawnError = null;
    final managed = await orch.spawn(
      SpawnSpec(
        id: kCompanionSessionId,
        role: 'companion',
        sessionId: _newSessionId(),
        cwd: root,
        visible: false,
        profile: SessionProfile.companion,
        systemPrompt: brief,
        model: kCompanionModel,
      ),
    );
    if (_stopped || !_enabled) {
      // The switch went off while the process was starting. Honour the later
      // intent rather than the one this call was issued under.
      await orch.close(kCompanionSessionId);
      return;
    }
    _managed = managed;
    _spawnedBrief = brief;
    _prompts = managed.session.pendingPromptStream.listen(_denyPrompt);
    notifyListeners();
  }

  Future<void> _teardown() async {
    await _prompts?.cancel();
    _prompts = null;
    final had = _managed != null;
    _managed = null;
    _spawnedBrief = null;
    await _orchestrator?.close(kCompanionSessionId);
    if (had && !_notifierDisposed) notifyListeners();
  }

  /// Refuse tool use — see [kCompanionToolDenial]. Quiet, because a refusal the
  /// companion did not ask a human for is not conversation.
  void _denyPrompt(ToolPrompt? prompt) {
    if (prompt == null) return;
    _managed?.session.resolvePrompt(prompt.promptId, const DenyTool(kCompanionToolDenial, quiet: true));
  }

  /// The primary was swapped for a different session — `/clear`, `/resume`, an
  /// account change. Only a replacement counts: the first attach has nothing to
  /// restart, and a bare detach is the gap between a respawn's two halves.
  void _onPrimaryChanged() {
    final now = _primary.managed;
    final before = _seenPrimary;
    if (now != null) _seenPrimary = now;
    if (now == null || before == null || identical(now, before)) return;
    unawaited(restart());
  }

  /// A completed turn arrived. Ask the trigger whether it is worth a prompt,
  /// and send it if so.
  ///
  /// The reason is derived here rather than by the digest, because it is a
  /// question about *spending*: a failed turn is worth asking about at every
  /// frequency, a quick lookup only at the chattiest.
  void _onDigest(DigestTurn turn) {
    final session = _managed?.session;
    if (session == null) return;
    final reason = turn.outcome.isError ? TriggerReason.turnFailed : TriggerReason.turnFinished;
    if (!_trigger.admit(reason, ran: turn.ran)) return;
    session.send(turn.text);
  }

  void _setIngesting(bool value) {
    if (_ingesting == value) return;
    _ingesting = value;
    if (!_notifierDisposed) notifyListeners();
  }
}
