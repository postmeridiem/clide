/// What Clide has spent this run (T-556, D-107).
///
/// The companion spends **the same subscription quota that rate-limits the
/// session the developer is actually driving** — D-107's own sharpest risk, and
/// until this existed it was the only one with no instrument. The kill switch
/// and the stingy trigger are both defences against a cost nobody could see.
///
/// ## "Lifetime" means this clide run
///
/// The ticket left the boundary open, and this is the answer: **per run**, and
/// deliberately not persisted. Nothing about the companion survives a restart
/// by design (D-107 as amended — his transcript is ordinary, his session is one
/// per run), so a total that spanned runs would need storage the initiative
/// chose not to have. Reopening that is a decision, not a detail, and it should
/// be made on purpose rather than by adding a file here.
///
/// Within a run it **does** span his session restarts — a `/clear` on the
/// primary, a language change, an edited brief. Those replace the process, and
/// a counter that reset with it would answer "what has this process spent",
/// which is not a question anyone has. That works because [SessionReader]
/// follows the orchestrator id rather than the session object, so a replacement
/// is invisible here.
///
/// ## Why it can just add
///
/// Every [TurnUsage] off the wire is a per-turn delta, including its cost —
/// `total_cost_usd` is cumulative on the wire and the session differences it
/// before publishing (T-556). So this class is a sum and a count, and the
/// subtlety it would otherwise carry lives one layer down where the wire is.
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_reader.dart';
import 'package:clide/builtin/claude/src/turn_signals.dart';
import 'package:clide/builtin/clide_companion/src/companion_session.dart';
import 'package:flutter/foundation.dart';

/// Running total of Clide's spend for this clide run.
class CompanionLedger extends ChangeNotifier {
  CompanionLedger({ClaudeSessionOrchestrator? orchestrator, SessionReader? reader}) : _reader = reader ?? companionSessionReader(orchestrator: orchestrator);

  final SessionReader _reader;
  StreamSubscription<TurnUsage>? _sub;
  var _started = false;

  TurnUsage _total = const TurnUsage();
  int _turns = 0;

  /// Everything he has spent this run, summed.
  TurnUsage get total => _total;

  /// How many turns he has taken — remarks plus answers plus the lifecycle
  /// notices he was told about. Not the same as "things he said": a turn where
  /// he chose silence still cost tokens, and that is exactly the sort of spend
  /// this surface exists to make visible.
  int get turns => _turns;

  /// Whether anything has been recorded yet. A fresh run has nothing to show,
  /// and showing a row of zeros would imply the instrument is broken.
  bool get isEmpty => _turns == 0;

  /// Begin following. Idempotent.
  void start() {
    if (_started) return;
    _started = true;
    _reader.start();
    _sub = _reader.turnUsage.listen(_onTurn);
  }

  void _onTurn(TurnUsage usage) {
    _total = _total + usage;
    _turns++;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reader.dispose();
    super.dispose();
  }
}
