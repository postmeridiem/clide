/// Primary-session load, onto the bus (T-538, D-107 commitment 5).
///
/// The **only** thing the companion reads from the primary session. Everything
/// else it knows comes from its own session (Epic D) or its own preferences
/// (T-527) — this one adapter is the whole width of the coupling, deliberately,
/// because the primary session is not ours and every extra thing read from it is
/// something Epic D has to agree with.
///
/// Adds no public API to `StreamJsonSession`: `busyStream` already exists and is
/// already consumed by the running indicator.
library;

import 'dart:async';

import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_reader.dart';
import 'package:clide/kernel/src/events/message_bus.dart';

/// Binds the primary session and republishes its busy state as `companion.load`.
///
/// Owns the turn-start timestamp. Nothing upstream records one — `_setBusy(true)`
/// has a single call site and keeps no time — so the rising edge is stamped here,
/// once, and carried on the message. A renderer that derived elapsed time from
/// when it happened to notice would drift by however long it took to notice.
class CompanionLoadAdapter {
  CompanionLoadAdapter({required MessageBus messages, DateTime Function()? now}) : _messages = messages, _now = now ?? DateTime.now;

  final MessageBus _messages;

  /// Injectable so a test can assert the stamped instant instead of racing it.
  final DateTime Function() _now;

  SessionReader? _reader;
  StreamSubscription<bool>? _busySub;
  StreamSubscription<Message>? _asks;

  bool _busy = false;
  DateTime? _busySince;
  bool _announced = false;

  /// Start watching. Safe to call more than once.
  void start(ClaudeSessionOrchestrator? orchestrator) {
    _reader?.dispose();
    // One subscription for the life of the adapter: the reader re-subscribes
    // across respawns underneath, so the cancel/rebind dance this class used to
    // own is gone (T-553). Absence still arrives here as `busy: false`, which
    // is what keeps stale weather off the strip.
    final reader = SessionReader.primary(orchestrator: orchestrator);
    _reader = reader;
    _busySub?.cancel();
    _busySub = reader.busy.listen((busy) => _set(busy: busy));
    // Renderers mount long after this first announcement — extensions activate
    // before `runApp` — so they ask, and this answers.
    _asks ??= _messages.subscribe(publisher: clideCompanionPublisher, channel: companionLoadAskChannel).listen((_) => _publish());
    reader.start();
  }

  void dispose() {
    _reader?.dispose();
    _reader = null;
    _busySub?.cancel();
    _busySub = null;
    _asks?.cancel();
    _asks = null;
  }

  void _set({required bool busy}) {
    if (_announced && busy == _busy) return;
    // Stamp only the rising edge: a turn that is still running keeps the instant
    // it began, or the counter would restart on every republish.
    if (busy && !_busy) _busySince = _now();
    if (!busy) _busySince = null;
    _busy = busy;
    _announced = true;
    _publish();
  }

  /// Announce the current value unconditionally — the answer to an ask, where
  /// the whole point is to repeat something the asker missed.
  void _publish() => publishCompanionLoad(_messages, busy: _busy, busySinceMs: _busySince?.millisecondsSinceEpoch);
}
