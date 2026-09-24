/// Caddy as the broker's child (D-120). The broker starts it once its own
/// socket is up, starts it again with backoff when it exits, and stops it
/// first on shutdown, so Caddy never serves with nothing behind it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Caddy exited while it was starting, which is a configuration problem,
/// such as a bad Caddyfile or a port already taken, rather than a crash to
/// retry.
class CaddyStartException implements Exception {
  CaddyStartException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class CaddySupervisor {
  CaddySupervisor({
    required this.executable,
    required this.config,
    required void Function(String line) log,
    this.startupGrace = const Duration(seconds: 5),
    this.steadyRun = const Duration(minutes: 1),
    Duration Function(int attempt)? backoff,
  }) : _log = log,
       _backoff = backoff ?? _doubling;

  final String executable;

  /// The Caddyfile Caddy runs.
  final String config;

  /// How long Caddy must stay up at first before it counts as started.
  final Duration startupGrace;

  /// How long a run must last for the next restart to wait the shortest time
  /// again.
  final Duration steadyRun;

  final void Function(String line) _log;
  final Duration Function(int attempt) _backoff;

  Process? _process;
  DateTime _startedAt = DateTime.now();
  Timer? _pending;
  int _attempt = 0;
  bool _stopping = false;

  /// How many times Caddy has been started again after exiting.
  int restarts = 0;

  /// Starts Caddy and waits out [startupGrace]. Caddy exiting within it
  /// throws [CaddyStartException]: something about this install stops it
  /// running, and retrying would only hide that.
  Future<void> start() async {
    final process = await _spawn();
    final exited = await Future.any<int?>([process.exitCode, Future<int?>.delayed(startupGrace)]);
    if (exited != null) {
      _process = null;
      throw CaddyStartException('Caddy exited while starting, with code $exited. Its own messages, marked "caddy:", say why.');
    }
    _watch(process);
  }

  /// Stops Caddy with SIGTERM, and with SIGKILL if it is still running after
  /// [grace]. A restart that was waiting does not happen.
  Future<void> stop({Duration grace = const Duration(seconds: 10)}) async {
    _stopping = true;
    _pending?.cancel();
    final process = _process;
    _process = null;
    if (process == null) return;
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(grace);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
  }

  Future<Process> _spawn() async {
    final process = await Process.start(executable, ['run', '--config', config, '--adapter', 'caddyfile']);
    _process = process;
    _startedAt = DateTime.now();
    for (final output in [process.stdout, process.stderr]) {
      output.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => _log('caddy: $line'));
    }
    return process;
  }

  void _watch(Process process) {
    unawaited(
      process.exitCode.then((code) {
        if (_stopping || !identical(process, _process)) return;
        _process = null;
        if (DateTime.now().difference(_startedAt) >= steadyRun) _attempt = 0;
        _restartLater('Caddy exited with code $code');
      }),
    );
  }

  void _restartLater(String why) {
    final wait = _backoff(_attempt++);
    _log('clide_broker: $why; starting it again in ${wait.inMilliseconds} ms');
    _pending = Timer(wait, () async {
      if (_stopping) return;
      final Process process;
      try {
        process = await _spawn();
      } on ProcessException catch (e) {
        _restartLater('Caddy could not be started: ${e.message}');
        return;
      }
      if (_stopping) {
        process.kill(ProcessSignal.sigterm);
        return;
      }
      restarts++;
      _watch(process);
    });
  }

  /// One second, then twice as long each time, up to 32 seconds.
  static Duration _doubling(int attempt) => Duration(seconds: 1 << (attempt < 5 ? attempt : 5));
}
