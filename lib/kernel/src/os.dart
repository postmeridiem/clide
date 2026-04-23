import 'dart:async';
import 'dart:io';

import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:flutter/foundation.dart';

class OsLifecycleEvent extends ClideEvent {
  const OsLifecycleEvent(this._kind);
  final String _kind;
  @override
  String get subsystem => 'os';
  @override
  String get kind => _kind;
}

class OsBridge {
  OsBridge({required Logger log, required DaemonBus events})
      : _log = log,
        _events = events;

  final Logger _log;
  final DaemonBus _events;

  Future<bool> openURL(String url) async {
    final cmd = _openCommand();
    if (cmd == null) {
      _log.warn('os', 'openURL unsupported on ${Platform.operatingSystem}');
      return false;
    }
    try {
      final r = await Process.run(cmd[0], [...cmd.skip(1), url]);
      return r.exitCode == 0;
    } catch (e) {
      _log.warn('os', 'openURL failed', error: e);
      return false;
    }
  }

  Future<bool> reveal(String path) async {
    final cmd = _revealCommand(path);
    if (cmd == null) return false;
    try {
      final r = await Process.run(cmd[0], cmd.skip(1).toList());
      return r.exitCode == 0;
    } catch (e) {
      _log.warn('os', 'reveal failed', error: e);
      return false;
    }
  }

  /// Fire an OS lifecycle event (called by the platform wiring).
  @visibleForTesting
  void fire(String kind) {
    _events.emit(OsLifecycleEvent(kind));
  }

  static List<String>? _openCommand() {
    if (Platform.isLinux) return ['xdg-open'];
    if (Platform.isMacOS) return ['open'];
    if (Platform.isWindows) return ['cmd', '/c', 'start', ''];
    return null;
  }

  static List<String>? _revealCommand(String path) {
    if (Platform.isLinux) return ['xdg-open', File(path).parent.path];
    if (Platform.isMacOS) return ['open', '-R', path];
    if (Platform.isWindows) return ['explorer', '/select,', path];
    return null;
  }
}
