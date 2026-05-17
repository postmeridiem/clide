import 'dart:async';
import 'dart:isolate';

import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:flutter/foundation.dart';

enum SchedulerTier {
  oneMinute(Duration(minutes: 1)),
  tenMinutes(Duration(minutes: 10)),
  fifteenMinutes(Duration(minutes: 15)),
  oneHour(Duration(hours: 1)),
  midnight(Duration(minutes: 1));

  const SchedulerTier(this.interval);
  final Duration interval;
}

@immutable
class SchedulerTick extends ClideEvent {
  const SchedulerTick({required this.tier});
  final SchedulerTier tier;

  @override
  String get subsystem => 'scheduler';
  @override
  String get kind => 'tick';
  @override
  Map<String, Object?> payload() => {'tier': tier.name};
}

class SchedulerService {
  SchedulerService(this._events);
  final DaemonBus _events;

  Isolate? _isolate;
  ReceivePort? _port;
  StreamSubscription<dynamic>? _sub;
  StreamSubscription<dynamic>? _projectSub;

  /// Tracks the spawn future so [_stopTicker] can await it before
  /// killing — otherwise a stop racing a still-spawning isolate
  /// leaves `_isolate` null at kill time and the just-spawned isolate
  /// (with its `Timer.periodic`) leaks forever. Same race shape we
  /// fixed in `NativePty` via `_readerReady` (T-96).
  Future<Isolate?>? _isolateReady;

  /// Listen for project lifecycle events. The periodic ticker only runs
  /// while a project is open — no wasted cycles on the welcome screen.
  void start() {
    _projectSub = _events.on<ProjectOpened>().listen((_) => _startTicker());
    _events.on<ProjectClosed>().listen((_) => _stopTicker());
  }

  /// Start the periodic ticker and fire an immediate first cycle so
  /// all panels refresh without waiting for the first interval.
  Future<void> _startTicker() async {
    await _stopTicker();

    // Stagger the initial ticks to avoid a rebuild storm on project open.
    var delay = 0;
    for (final tier in SchedulerTier.values) {
      if (tier == SchedulerTier.midnight) continue;
      Timer(Duration(milliseconds: delay), () {
        _events.emit(SchedulerTick(tier: tier));
      });
      delay += 500;
    }

    // Then start the periodic isolate.
    _port = ReceivePort();
    _sub = _port!.listen((msg) {
      if (msg is String) {
        final tier = SchedulerTier.values.firstWhere((t) => t.name == msg);
        _events.emit(SchedulerTick(tier: tier));
      }
    });
    _isolateReady = Isolate.spawn(_isolateEntry, _port!.sendPort);
    _isolateReady!.then((iso) => _isolate = iso).catchError((_) => null);
  }

  Future<void> _stopTicker() async {
    // Await any in-flight spawn so we never miss killing an isolate
    // that's mid-creation — see _isolateReady.
    if (_isolateReady != null) {
      try {
        final pending = await _isolateReady;
        _isolate ??= pending;
      } catch (_) {
        // Spawn failed; nothing to kill.
      }
    }
    _sub?.cancel();
    _port?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _isolateReady = null;
    _port = null;
    _sub = null;
  }

  static void _isolateEntry(SendPort send) {
    int lastDay = DateTime.now().day;
    for (final tier in SchedulerTier.values) {
      if (tier == SchedulerTier.midnight) {
        Timer.periodic(const Duration(minutes: 1), (_) {
          final day = DateTime.now().day;
          if (day != lastDay) {
            lastDay = day;
            send.send(tier.name);
          }
        });
        continue;
      }
      Timer.periodic(tier.interval, (_) => send.send(tier.name));
    }
  }

  Future<void> dispose() async {
    _projectSub?.cancel();
    await _stopTicker();
  }
}
