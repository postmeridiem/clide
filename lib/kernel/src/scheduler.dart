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

  void start() {
    if (_isolate != null) return;
    _port = ReceivePort();
    _sub = _port!.listen((msg) {
      if (msg is String) {
        final tier = SchedulerTier.values.firstWhere((t) => t.name == msg);
        _events.emit(SchedulerTick(tier: tier));
      }
    });
    Isolate.spawn(_isolateEntry, _port!.sendPort).then((iso) => _isolate = iso);
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

  void dispose() {
    _sub?.cancel();
    _port?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port = null;
    _sub = null;
  }
}
