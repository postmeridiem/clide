/// What Clide is saying and how he looks (T-548, D-107 commitment 5).
///
/// The seam Epics B and E consume. It reads **his** session — not the primary's
/// — and turns it into the two things the strip renders: a face and a remark.
///
/// ## No bus channel, deliberately
///
/// The obvious shape was a `companion.say` channel. T-561 removed the last one
/// of those and recorded why: a bus is for signals that **span surfaces**, and
/// `companion.set`/`companion.state` earn their place because a rail button in
/// the status bar and a strip in the context column must agree. A remark spans
/// nothing — it goes from his session to the widget beside it. Putting it on the
/// bus would mean a channel, a publisher, and a retention problem to solve
/// again, to move a string one layer.
///
/// So this binds [companionSessionReader] directly, which is what T-555 built it
/// for.
///
/// ## Only finished replies are rendered
///
/// His text is parsed on the turn's `result`, never as items arrive. Caught
/// live: parsing each item put **`[idle`** — an unclosed face tag, mid-stream —
/// straight into the bubble, which is precisely the failure T-532's kill
/// condition names. A `partial-` uuid means "came through the streaming path",
/// not "still arriving", and the final event is rewritten under the same uuid,
/// so the only safe read is at the turn boundary. Same rule the digest follows,
/// arrived at the same way.
///
/// The *face* still moves during a turn, because that comes from
/// [TurnPhase] rather than from his text — he looks like he is thinking while he
/// is thinking, and only the words wait.
///
/// ## Two sources for one face
///
/// Mechanics win over mood. His session dying, his request being in flight and
/// his reply streaming are **facts**, and a declared mood that contradicted one
/// would be a lie the user can see — a cheerful face on a dead session. So the
/// declared mood only fills the gap where nothing mechanical is happening, which
/// is most of the time and is where a character lives anyway.
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_reader.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart' show SessionEnd;
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/builtin/claude/src/turn_signals.dart';
import 'package:clide/builtin/clide_companion/src/companion_session.dart';
import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:clide/builtin/clide_companion/src/prompt/companion_reply.dart';
import 'package:flutter/foundation.dart';

/// How long a remark stays on screen.
///
/// A bubble that never clears is three problems at once: it goes stale (the
/// thing it was about was fixed an hour ago), it is what a colleague sees on a
/// shared screen long after the moment, and it makes him look like he is still
/// talking. Long enough to read twice, short enough that an idle strip is a
/// quiet one.
const kRemarkDwell = Duration(minutes: 2);

/// Binds Clide's own session and exposes what to draw.
class CompanionVoice extends ChangeNotifier {
  CompanionVoice({ClaudeSessionOrchestrator? orchestrator, SessionReader? reader, bool Function()? moodEnabled})
    : _reader = reader ?? companionSessionReader(orchestrator: orchestrator),
      _moodEnabled = moodEnabled ?? _yes;

  static bool _yes() => true;

  final SessionReader _reader;

  /// Whether a declared mood is honoured. Off, expression comes from his session
  /// lifecycle alone — D-107's own stated fallback. Read live, so the setting
  /// applies without a restart.
  final bool Function() _moodEnabled;

  final _subs = <StreamSubscription<Object?>>[];
  Timer? _dwell;
  var _started = false;

  /// The mood he last named, held until he names another. Null until he has.
  FaceState? _declared;

  /// Text in flight, keyed by uuid so a streamed message and its final rewrite
  /// collapse into one entry with the complete version winning.
  final Map<String, String> _pending = {};
  TurnPhase _phase = TurnPhase.idle;
  bool _dead = false;
  String? _say;

  /// What the face should show right now.
  ///
  /// Mechanics first: a declared mood that contradicted a fact would be visibly
  /// wrong. [FaceState.idle] rather than null when he has never spoken, because
  /// the strip always draws something.
  FaceState get face {
    if (_dead) return FaceState.error;
    return switch (_phase) {
      TurnPhase.thinking => FaceState.pensive,
      TurnPhase.answering => FaceState.speaking,
      TurnPhase.idle => (_moodEnabled() ? _declared : null) ?? FaceState.idle,
    };
  }

  /// His current remark, or null when he has nothing to say — which is the
  /// normal state.
  String? get say => _say;

  /// Begin following. Idempotent.
  void start() {
    if (_started) return;
    _started = true;
    _reader.start();
    _subs
      ..add(_reader.items.listen(_onItem))
      ..add(_reader.turnOutcomes.listen(_onTurnEnd))
      ..add(_reader.phase.listen(_onPhase))
      ..add(_reader.ended.listen(_onEnded));
  }

  @override
  void dispose() {
    _dwell?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _reader.dispose();
    super.dispose();
  }

  void _onItem(ConversationItem item) {
    // Only his prose. His own session echoes the digest back as UserMessages —
    // those are what WE said to him, and rendering them would put the developer's
    // own conversation in Clide's mouth.
    if (item is! AssistantTextMessage || item.synthetic) return;
    // Held, not parsed. Mid-stream this is a fragment — `[idle` with no closing
    // bracket — and parsing it renders scaffolding.
    _pending[item.uuid] = item.text;
  }

  /// He finished. Now his text can be trusted.
  void _onTurnEnd(TurnOutcome outcome) {
    if (_pending.isEmpty) return;
    final reply = parseCompanionReply(_pending.values.join('\n'));
    _pending.clear();

    // A face he did not name, or named unrecognisably, leaves the previous
    // expression alone (T-532's kill condition). Never a default reset: an
    // unchanged face reads as having nothing new to feel, a snap to neutral
    // reads as a glitch.
    if (reply.face != null) _declared = reply.face;

    if (reply.speaks) {
      _say = reply.say;
      _dwell?.cancel();
      _dwell = Timer(kRemarkDwell, _clearRemark);
    }
    // Silence is not an instruction to clear what is on screen — he simply had
    // nothing to add to it. The dwell timer is what clears.
    _dead = false;
    notifyListeners();
  }

  void _clearRemark() {
    if (_say == null) return;
    _say = null;
    notifyListeners();
  }

  void _onPhase(TurnPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    notifyListeners();
  }

  void _onEnded(SessionEnd end) {
    // His session dying is not the primary's dying: the rain keeps reporting the
    // weather, and only the face goes out.
    if (_dead) return;
    _dead = true;
    notifyListeners();
  }
}
