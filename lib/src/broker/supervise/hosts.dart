/// The workspace hosts (D-117, D-120): one process per workspace, started on
/// the first attach and, once it has exited, by the next one, with backoff
/// against a crash loop. A host is never stopped for being idle: the broker
/// does not speak its protocol, so it cannot tell a quiet workspace from one
/// where Claude works with no tab open.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../ipc/paths.dart';

/// A workspace's host could not be started, or did not answer in time.
final class HostStartException implements Exception {
  HostStartException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What the session endpoint needs from the hosts.
abstract interface class WorkspaceHosts {
  /// The socket of [workspace]'s host, once it answers there.
  Future<String> attach(String workspace);
}

/// The environment a host starts with: the broker's, without the broker's
/// own variables, some of which are secrets that a host and everything it
/// runs must never see (D-121), and with the hosts' runtime directory (D-70).
Map<String, String> hostEnvironment(Map<String, String> broker, String runtimeDirectory) => {
  for (final e in withoutWindowIdentity(broker).entries)
    if (!e.key.startsWith('CLIDE_BROKER_')) e.key: e.value,
  'XDG_RUNTIME_DIR': runtimeDirectory,
};

final class HostManager implements WorkspaceHosts {
  HostManager({
    required this.executable,
    required this.runtimeDirectory,
    required Map<String, String> environment,
    required void Function(String line) log,
    this.readyTimeout = const Duration(seconds: 30),
    this.steadyRun = const Duration(minutes: 1),
    Duration Function(int attempt)? backoff,
  }) : _environment = hostEnvironment(environment, runtimeDirectory),
       _log = log,
       _backoff = backoff ?? _doubling;

  /// The host program, started as `<executable> --workspace <folder>`.
  final String executable;

  /// The hosts' `XDG_RUNTIME_DIR`. Each host listens on D-70's path under it.
  final String runtimeDirectory;

  /// How long a new host has to answer on its socket.
  final Duration readyTimeout;

  /// How long a host must run for its exit not to count as a crash.
  final Duration steadyRun;

  final Map<String, String> _environment;
  final void Function(String line) _log;
  final Duration Function(int attempt) _backoff;
  final _hosts = <String, _Host>{};
  final _crashes = <String, ({int count, DateTime at})>{};
  bool _stopping = false;

  /// Where [workspace]'s host listens (D-70).
  String socketPath(String workspace) => workspaceSocketPath(workspace, directory: '$runtimeDirectory/clide');

  /// Attaches that arrive while a host starts share that start. Once [stop]
  /// has run, every attach fails.
  @override
  Future<String> attach(String workspace) {
    final running = _hosts[workspace];
    if (running != null) return running.ready;
    final host = _hosts[workspace] = _Host(workspace);
    return host.ready = _start(host);
  }

  /// Stops every host with SIGTERM, and with SIGKILL if one is still running
  /// after [grace]. Nothing starts afterwards.
  Future<void> stop({Duration grace = const Duration(seconds: 10)}) async {
    _stopping = true;
    final running = [for (final host in _hosts.values) ?host.process];
    for (final process in running) {
      process.kill(ProcessSignal.sigterm);
    }
    final exited = Future.wait([for (final process in running) process.exitCode]);
    try {
      await exited.timeout(grace);
    } on TimeoutException {
      for (final process in running) {
        process.kill(ProcessSignal.sigkill);
      }
      await exited;
    }
  }

  Future<String> _start(_Host host) async {
    final name = _name(host.workspace);
    final crash = _crashes[host.workspace];
    if (crash != null) {
      final wait = crash.at.add(_backoff(crash.count - 1)).difference(DateTime.now());
      if (wait > Duration.zero) {
        _log('host $name: starting it again in ${wait.inMilliseconds} ms');
        await Future<void>.delayed(wait);
      }
    }
    if (_stopping) {
      _forget(host);
      throw HostStartException('The broker is stopping.');
    }
    final path = socketPath(host.workspace);
    final Process process;
    try {
      process = await Process.start(
        executable,
        ['--workspace', host.workspace],
        workingDirectory: host.workspace,
        environment: _environment,
        includeParentEnvironment: false,
      );
    } on ProcessException catch (e) {
      _forget(host);
      _crashed(host.workspace);
      throw HostStartException('The host for $name could not be started: ${e.message}');
    }
    host
      ..process = process
      ..startedAt = DateTime.now();
    for (final output in [process.stdout, process.stderr]) {
      output.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => _log('host $name: $line'));
    }
    unawaited(process.exitCode.then((code) => _exited(host, code)));
    final deadline = DateTime.now().add(readyTimeout);
    while (true) {
      final code = host.exitCode;
      if (code != null) throw HostStartException('The host for $name exited with code $code before it answered.');
      if (await _answers(path)) return path;
      if (DateTime.now().isAfter(deadline)) {
        process.kill(ProcessSignal.sigkill);
        throw HostStartException('The host for $name did not answer on its socket within ${_describe(readyTimeout)}.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void _exited(_Host host, int code) {
    host.exitCode = code;
    _forget(host);
    if (_stopping) return;
    final ran = DateTime.now().difference(host.startedAt);
    if (ran >= steadyRun) {
      _crashes.remove(host.workspace);
      _log('host ${_name(host.workspace)}: exited with code $code');
    } else {
      _crashed(host.workspace);
      _log('host ${_name(host.workspace)}: exited with code $code after ${ran.inMilliseconds} ms');
    }
  }

  void _crashed(String workspace) {
    final previous = _crashes[workspace];
    _crashes[workspace] = (count: (previous?.count ?? 0) + 1, at: DateTime.now());
  }

  void _forget(_Host host) {
    if (identical(_hosts[host.workspace], host)) _hosts.remove(host.workspace);
  }

  static Future<bool> _answers(String path) async {
    try {
      (await Socket.connect(InternetAddress(path, type: InternetAddressType.unix), 0, timeout: const Duration(seconds: 1))).destroy();
      return true;
    } on SocketException {
      return false;
    }
  }

  static String _name(String workspace) => workspace.split('/').lastWhere((s) => s.isNotEmpty, orElse: () => workspace);

  static String _describe(Duration d) => d.inMilliseconds % 1000 == 0 ? '${d.inSeconds} s' : '${d.inMilliseconds} ms';

  /// One second, then twice as long each time, up to 32 seconds.
  static Duration _doubling(int attempt) => Duration(seconds: 1 << (attempt < 5 ? attempt : 5));
}

final class _Host {
  _Host(this.workspace);

  final String workspace;
  late Future<String> ready;
  Process? process;
  DateTime startedAt = DateTime.now();
  int? exitCode;
}
