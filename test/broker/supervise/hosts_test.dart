@TestOn('!windows')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/broker/supervise/hosts.dart';
import 'package:clide/src/ipc/paths.dart';
import 'package:test/test.dart';

/// The workspace hosts (D-120), against the stub host and shell stand-ins.
void main() {
  late Directory dir;
  late String runtime;
  late String workspace;
  late List<String> lines;
  final stub = '${Directory.current.path}/bin/clide_stub_host.dart';

  setUp(() {
    dir = Directory.systemTemp.createTempSync('clide-hosts-');
    runtime = '${dir.path}/run';
    workspace = '${dir.path}/demo';
    Directory(workspace).createSync();
    lines = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// A host program: a shell script running [body] in the workspace, where
  /// `$STUB` starts the stub host.
  String host(String body) {
    final file = File('${dir.path}/host')..writeAsStringSync('#!/bin/sh\nSTUB="dart run $stub"\n$body\n');
    Process.runSync('chmod', ['755', file.path]);
    return file.path;
  }

  HostManager manage(
    String executable, {
    Map<String, String> environment = const {},
    Duration readyTimeout = const Duration(seconds: 20),
    Duration steadyRun = const Duration(minutes: 1),
    Duration Function(int attempt)? backoff,
  }) => HostManager(
    executable: executable,
    runtimeDirectory: runtime,
    environment: {'PATH': Platform.environment['PATH']!, ...environment},
    log: lines.add,
    readyTimeout: readyTimeout,
    steadyRun: steadyRun,
    backoff: backoff ?? (_) => const Duration(milliseconds: 20),
  );

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 500 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(condition(), isTrue);
  }

  /// The first line a host sends on a new connection to [path].
  Future<String> greeting(String path) async {
    final socket = await Socket.connect(InternetAddress(path, type: InternetAddressType.unix), 0);
    final line = await utf8.decoder.bind(socket).transform(const LineSplitter()).first;
    socket.destroy();
    return line;
  }

  test("a host's environment has its runtime directory, and none of the broker's own variables", () {
    final environment = hostEnvironment({
      'PATH': '/bin',
      'CLIDE_BROKER_STORE_PASSWORD': 'hunter2',
      'CLIDE_BROKER_PUBLIC_ORIGIN': 'https://clide.test',
      'CLIDE_SOCK': '/another/window.sock',
      'XDG_RUNTIME_DIR': '/run/user/1000',
    }, '/clide/state/run');
    expect(environment, {'PATH': '/bin', 'XDG_RUNTIME_DIR': '/clide/state/run'});
  });

  test('the first attach starts the host with --workspace, and answers its D-70 socket', () async {
    final hosts = manage(host(r'echo "$@" > args; exec $STUB "$@"'));
    addTearDown(hosts.stop);
    final path = await hosts.attach(workspace);
    expect(path, workspaceSocketPath(workspace, directory: '$runtime/clide'));
    expect(await greeting(path), 'clide stub host for demo');
    expect(File('$workspace/args').readAsStringSync().trim(), '--workspace $workspace');
    expect((FileStat.statSync('$runtime/clide').mode & 0x1ff).toRadixString(8), '700');
  });

  test('attaches that arrive together share one start, and later ones reuse the host', () async {
    final hosts = manage(host(r'echo start >> starts; exec $STUB "$@"'));
    addTearDown(hosts.stop);
    final paths = await Future.wait([hosts.attach(workspace), hosts.attach(workspace)]);
    expect(paths.toSet(), hasLength(1));
    await hosts.attach(workspace);
    expect(File('$workspace/starts').readAsLinesSync(), hasLength(1));
  });

  test('a started host sees none of the broker\'s own variables', () async {
    final hosts = manage(
      host(r'env > environment; exec $STUB "$@"'),
      environment: {'CLIDE_BROKER_OIDC_CLIENT_SECRET': 'hunter2', 'CLIDE_BROKER_STORE': 'sqlite:/x.db', 'LANG': 'C.UTF-8'},
    );
    addTearDown(hosts.stop);
    await hosts.attach(workspace);
    final seen = File('$workspace/environment').readAsStringSync();
    expect(seen, allOf(contains('XDG_RUNTIME_DIR=$runtime\n'), contains('LANG=C.UTF-8'), isNot(contains('CLIDE_BROKER_')), isNot(contains('hunter2'))));
  });

  test('a host that exits before it answers is reported, and the next attach waits out the backoff', () async {
    final hosts = manage(host('echo start >> starts; echo "bad config" >&2; exit 3'), backoff: (_) => const Duration(milliseconds: 300));
    addTearDown(hosts.stop);
    await expectLater(
      hosts.attach(workspace),
      throwsA(isA<HostStartException>().having((e) => e.message, 'message', contains('exited with code 3 before it answered'))),
    );
    final waited = Stopwatch()..start();
    await expectLater(hosts.attach(workspace), throwsA(isA<HostStartException>()));
    expect(waited.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 250)));
    expect(lines, containsAll([contains('host demo: bad config'), contains('host demo: starting it again in')]));
    expect(File('$workspace/starts').readAsLinesSync(), hasLength(2));
  });

  test('each crash in a row backs off longer', () async {
    final attempts = <int>[];
    final hosts = manage(
      host('exit 1'),
      backoff: (attempt) {
        attempts.add(attempt);
        return const Duration(milliseconds: 10);
      },
    );
    addTearDown(hosts.stop);
    for (var i = 0; i < 4; i++) {
      await expectLater(hosts.attach(workspace), throwsA(isA<HostStartException>()));
    }
    expect(attempts, [0, 1, 2]);
  });

  test('a host that ran steadily starts again at once after it exits', () async {
    final hosts = manage(host(r'echo $$ > pid; exec $STUB "$@"'), steadyRun: const Duration(milliseconds: 100), backoff: (_) => const Duration(seconds: 10));
    addTearDown(hosts.stop);
    await hosts.attach(workspace);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    Process.killPid(int.parse(File('$workspace/pid').readAsStringSync().trim()));
    await until(() => lines.any((l) => l.contains('host demo: exited with code 0')));
    final again = Stopwatch()..start();
    expect(await greeting(await hosts.attach(workspace)), 'clide stub host for demo');
    expect(again.elapsed, lessThan(const Duration(seconds: 5)));
    expect(lines.where((l) => l.contains('starting it again')), isEmpty);
  });

  test('a host that never answers is killed once the ready timeout passes', () async {
    final hosts = manage(host(r'echo $$ > pid; exec sleep 30'), readyTimeout: const Duration(milliseconds: 500));
    addTearDown(hosts.stop);
    await expectLater(
      hosts.attach(workspace),
      throwsA(isA<HostStartException>().having((e) => e.message, 'message', contains('did not answer on its socket within 500 ms'))),
    );
    final pid = File('$workspace/pid').readAsStringSync().trim();
    await until(() => Process.runSync('kill', ['-0', pid]).exitCode != 0);
  });

  test('a host program that cannot be run is reported', () async {
    final hosts = manage('${dir.path}/no-such-host');
    await expectLater(hosts.attach(workspace), throwsA(isA<HostStartException>().having((e) => e.message, 'message', contains('could not be started'))));
  });

  test('stop ends the hosts with SIGTERM, and nothing starts afterwards', () async {
    final hosts = manage(host(r'exec $STUB "$@"'));
    final path = await hosts.attach(workspace);
    await hosts.stop();
    expect(File(path).existsSync(), isFalse, reason: 'the stub removes its socket when SIGTERM stops it');
    await expectLater(hosts.attach(workspace), throwsA(isA<HostStartException>().having((e) => e.message, 'message', contains('stopping'))));
  });

  test('stop sends SIGKILL to a host that ignores SIGTERM', () async {
    final hosts = manage(host(r"echo $$ > pid; trap '' TERM; while true; do sleep 0.1; done"));
    unawaited(hosts.attach(workspace).then<void>((_) {}, onError: (Object _) {}));
    await until(() => File('$workspace/pid').existsSync());
    final stopping = Stopwatch()..start();
    await hosts.stop(grace: const Duration(milliseconds: 300));
    expect(stopping.elapsed, allOf(greaterThanOrEqualTo(const Duration(milliseconds: 300)), lessThan(const Duration(seconds: 5))));
    final pid = File('$workspace/pid').readAsStringSync().trim();
    expect(Process.runSync('kill', ['-0', pid]).exitCode, isNot(0));
  });
}
