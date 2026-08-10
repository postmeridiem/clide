/// What Clide is allowed to see (T-546, D-107 commitment 3).
///
/// Turns the primary session's conversation into the handful of lines Clide is
/// fed. Everything interesting here is about what does **not** get through.
///
/// ## An allow-list, deliberately
///
/// [_admit] names the two types that pass and drops everything else, including
/// types that do not exist yet. A deny-list would be the same code today and a
/// leak tomorrow: a new item type added to the sealed union would flow straight
/// to a second model with nobody deciding it should. The compiler cannot help —
/// a sealed class buys exhaustiveness on `switch`, not on "did anyone think
/// about this" — so the shape of the code has to.
///
/// D-107 commitment 3 makes this a **scope and privacy boundary, not a
/// formatting choice**: tool activity is where file contents, paths, credentials
/// and command output live. Any future feature needing Clide to see tool
/// activity amends that record. It must not become a config flag by accident,
/// and it must not become one here.
///
/// **Accepted consequence:** "what did that tool call do?" is unanswerable. What
/// Claude *said* is visible; what Claude *did* is not.
///
/// ## One line per completed exchange, not per token
///
/// The digest flushes on the turn's `result`, never on an item arriving. That is
/// not an optimisation — it is the only correct trigger, because a `partial-`
/// uuid does **not** mean "still arriving": the final assistant event is
/// rewritten carrying the same uuid it streamed under (found in Epic B's signal
/// audit). Keying by uuid and letting later text win therefore collapses a dozen
/// streaming updates and the final rewrite into one line, and waiting for the
/// turn boundary means we always read the finished version.
///
/// ## Absence is silence
///
/// A turn yielding nothing admissible produces **no prompt at all** — not an
/// empty one, not a "nothing happened" one. Every line sent is an invitation to
/// reply, and a line describing emptiness invites a remark about emptiness,
/// which he would be right to make because we told him something. A session
/// ending, a session not existing, and a paused ingest are likewise silent.
///
/// That rule governs this file only. `SessionLoad` keeps reporting absence to
/// the rain, or the strip shows stale weather. One is a signal to a painter, the
/// other is text to a model.
///
/// ## Pausing is dropping, not buffering
///
/// While ingest is off (the strip minimised, T-528/T-545) items are **discarded**
/// rather than queued. A minimised stretch is conversation Clide genuinely did
/// not see, which is the honest privacy story; replaying it on restore would
/// make the pause a lie and would bury him in backlog at the moment he became
/// visible again. The gap is narrated once on resume instead (T-532's detach
/// notice).
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/session_reader.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/builtin/claude/src/turn_signals.dart';
import 'package:clide/builtin/clide_companion/src/prompt/digest_lines.dart';

/// The prose a turn contained, in arrival order.
class _Turn {
  /// Keyed by uuid so a streamed message and its final rewrite collapse into
  /// one entry, with the later (complete) text winning.
  final Map<String, String> prompts = {};
  final Map<String, String> prose = {};

  bool get isEmpty => prompts.isEmpty && prose.isEmpty;

  void clear() {
    prompts.clear();
    prose.clear();
  }
}

/// Reads the primary session and emits one digest line-pair per completed turn.
class CompanionDigest {
  CompanionDigest({required SessionReader source, bool Function()? ingesting}) : _source = source, _ingesting = ingesting ?? _always;

  static bool _always() => true;

  final SessionReader _source;

  /// Consulted at the moment each item arrives, not at flush: whether Clide was
  /// watching *then* is what decides whether he saw it.
  final bool Function() _ingesting;

  final _turn = _Turn();
  final _lines = StreamController<String>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];
  var _started = false;

  /// The digest, one entry per completed exchange that had anything in it.
  Stream<String> get lines => _lines.stream;

  /// Begin following. Idempotent.
  void start() {
    if (_started || _lines.isClosed) return;
    _started = true;
    _subs
      ..add(_source.items.listen(_onItem))
      ..add(_source.turnOutcomes.listen(_onTurnEnd));
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _lines.close();
  }

  void _onItem(ConversationItem item) {
    if (!_ingesting()) return;
    _admit(item);
  }

  /// The allow-list. Anything not named here never reaches Clide.
  void _admit(ConversationItem item) {
    // Sub-agent traffic is somebody else's conversation about somebody else's
    // task, and it carries the same tool-shaped content the boundary exists to
    // exclude. Not the conversation he is watching.
    if (item.isSidechain || item.parentToolUseId != null) return;

    switch (item) {
      case UserMessage(:final text, :final injected, :final uuid):
        // Harness-injected "user" messages — skill loads, slash expansions,
        // system reminders — were not typed by anyone. Passing them on would
        // have Clide watching the developer say things they never said.
        if (injected) return;
        _put(_turn.prompts, uuid, text);
      case AssistantTextMessage(:final text, :final synthetic, :final uuid):
        // Synthetic prose is the CLI or clide talking locally, not the model:
        // /usage output, "that isn't available here", our own injected notices.
        // Clide commenting on clide's own chrome is the tooling-narration
        // failure this whole surface is meant to avoid.
        if (synthetic) return;
        _put(_turn.prose, uuid, text);
      // Everything else is out, and stays out until D-107 says otherwise:
      // tool calls, tool results, thinking, and the injected image/drawing/icon
      // cards. Named rather than defaulted so the omission is visible.
      case ToolResultMessage() || AssistantToolUse() || AssistantThinkingMessage() || ImageMessage() || DrawingMessage() || IconMessage():
        return;
    }
  }

  static void _put(Map<String, String> into, String uuid, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    into[uuid] = t;
  }

  /// A turn finished. Emit what it contained, if anything.
  ///
  /// [outcome] is not read here — whether the turn failed is a *trigger*
  /// question, and triggers are T-547's. This ticket decides only what may be
  /// seen and how it is framed.
  void _onTurnEnd(TurnOutcome outcome) {
    if (_turn.isEmpty) {
      // Nothing admissible happened — a turn that was all tool work, or one
      // that ran entirely while minimised. No prompt at all.
      _turn.clear();
      return;
    }
    final line = observedExchange(prompt: _turn.prompts.values.join('\n'), reply: _turn.prose.values.join('\n\n'));
    _turn.clear();
    if (line != null && !_lines.isClosed) _lines.add(line);
  }
}
