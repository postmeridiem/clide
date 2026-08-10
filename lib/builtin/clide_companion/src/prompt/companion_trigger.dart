/// When Clide is *asked* to say something (T-547, D-107).
///
/// Two filters sit between a conversation and a remark, and they answer
/// different questions. **This one decides whether to spend anything at all** —
/// every prompt sent draws on the same quota pool already rate-limiting the
/// session the developer is actually driving, so the cost is not money but their
/// own throughput. **The brief decides whether to speak**, once asked, and
/// measured at roughly one remark per eight exchanges.
///
/// Keeping them separate matters: a model cannot be trusted to bound its own
/// spend, because deciding not to answer still costs a turn.
///
/// ## State changes are not events
///
/// [TriggerReason] deliberately has no member for a session starting, ending,
/// being minimised or coming back. Those are things the *tooling* did, not
/// things that happened in the work, and the signals for all of them are
/// conveniently to hand (T-557 surfaces turn outcome, T-551 forwards binding
/// changes) — which is exactly how an ambient surface becomes a nuisance.
/// Availability is not a reason to speak. Encoding it in the enum rather than in
/// a comment means the omission has to be argued for, not merely forgotten.
///
/// ## What is missing, and why
///
/// D-107's fourth notable event is a commit landing. There is no producer for it
/// here: detecting one means watching the git subsystem, which is a second
/// source with its own lifecycle, and the brief already catches commits from the
/// conversation ("Committed without a changelog entry" is prose). Added when
/// something needs it, not before.
library;

import 'package:clide/builtin/clide_companion/src/companion_settings.dart';

/// Why Clide is being handed something.
enum TriggerReason {
  /// A turn completed normally.
  turnFinished,

  /// A turn ended in failure — the CLI's own verdict, or the API's.
  turnFailed,

  /// A turn has been running longer than [kLongRunThreshold]. Fires **once per
  /// turn**, not once per check: a threshold that re-arms is a metronome.
  longRun,
}

/// How long a turn runs before it counts as a long one.
///
/// Two minutes because a turn that long is one the developer has probably
/// stopped watching, which is the moment an ambient surface earns its place.
const kLongRunThreshold = Duration(minutes: 2);

/// A completed turn that produced nothing worth calling substantial: a lookup, a
/// one-word confirmation. Only [CompanionFrequency.chatty] is handed these.
const kTrivialTurn = Duration(seconds: 5);

/// The minimum gap between two things Clide is asked about, per frequency.
///
/// This is the backstop the ticket asks for — `max_tokens` bounds one reply and
/// nothing bounded replies per minute. It is not the primary control; the brief
/// is. It exists so that no burst of activity can turn into a burst of prompts.
const kMinGap = <CompanionFrequency, Duration>{
  CompanionFrequency.rare: Duration(minutes: 10),
  CompanionFrequency.notable: Duration(minutes: 1),
  CompanionFrequency.chatty: Duration(seconds: 10),
};

/// Collapses events arriving together into one.
///
/// "Turn finished" and "commit landed" can land within a second of each other,
/// and two remarks about one event reads as a malfunction. Distinct from
/// [kMinGap]: this is about one *occurrence* producing two signals, that is
/// about pacing over time.
const kDebounce = Duration(seconds: 10);

/// Decides which events become prompts. Pure but for its clock.
class CompanionTrigger {
  CompanionTrigger({required CompanionFrequency Function() frequency, DateTime Function()? now}) : _frequency = frequency, _now = now ?? DateTime.now;

  final CompanionFrequency Function() _frequency;
  final DateTime Function() _now;

  DateTime? _lastSent;
  bool _longRunFired = false;

  /// Whether [reason] should be sent, given how long the turn ran.
  ///
  /// [ran] is the turn's duration; it decides whether a completed turn was
  /// substantial enough for [CompanionFrequency.notable], and is ignored for the
  /// other reasons.
  bool admit(TriggerReason reason, {Duration ran = Duration.zero}) {
    if (!_qualifies(reason, ran)) return false;

    final now = _now();
    final last = _lastSent;
    if (last != null) {
      final since = now.difference(last);
      // Debounce first so the message is honest in a log: two signals for one
      // occurrence is a different problem from going too fast.
      if (since < kDebounce) return false;
      if (since < (kMinGap[_frequency()] ?? kDebounce)) return false;
    }
    if (reason == TriggerReason.longRun) _longRunFired = true;
    _lastSent = now;
    return true;
  }

  /// The frequency gate, before any pacing.
  bool _qualifies(TriggerReason reason, Duration ran) {
    // A long run fires once per turn. Re-arming it would make a slow turn tick.
    if (reason == TriggerReason.longRun && _longRunFired) return false;

    return switch (_frequency()) {
      // Errors and long runs. Someone who wants the face and the rain but
      // rarely the voice — and note this is the *only* rung where a good day
      // produces silence, which is a real hazard: it makes his entire
      // observable behaviour a commentary on failure.
      CompanionFrequency.rare => reason != TriggerReason.turnFinished,

      // The default. Everything above, plus completed turns that were
      // substantial — a sub-five-second lookup is not an occasion, and asking
      // him about one spends a turn to be told nothing.
      CompanionFrequency.notable => reason != TriggerReason.turnFinished || ran >= kTrivialTurn,

      // Every completed exchange, however small.
      CompanionFrequency.chatty => true,
    };
  }

  /// A new turn began: re-arm the long-run threshold.
  void turnStarted() => _longRunFired = false;
}
