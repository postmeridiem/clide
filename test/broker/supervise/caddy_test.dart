@TestOn('!windows')
library;

import 'dart:async';
import 'dart:io';

import 'package:clide/src/broker/supervise/caddy.dart';
import 'package:test/test.dart';

/// Stand-ins for Caddy, as shell scripts: what the supervisor sees of a
/// Caddy that runs, one that fails at once, one that crashes later and one
/// that ignores SIGTERM.
void main() {
  late Directory dir;
  late List<String> lines;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('clide-caddy-');
    lines = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  String standIn(String name, String body) {
    final file = File('${dir.path}/$name')..writeAsStringSync('#!/bin/sh\n$body\n');
    Process.runSync('chmod', ['755', file.path]);
    return file.path;
  }

  CaddySupervisor supervise(String executable, {Duration grace = const Duration(milliseconds: 200), Duration Function(int)? backoff}) => CaddySupervisor(
    executable: executable,
    config: '/etc/caddy/Caddyfile',
    log: lines.add,
    startupGrace: grace,
    steadyRun: const Duration(seconds: 5),
    backoff: backoff ?? (_) => const Duration(milliseconds: 20),
  );

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(condition(), isTrue);
  }

  test('runs Caddy with its config, passes its output on, and stops it with SIGTERM', () async {
    final caddy = supervise(standIn('caddy', r'echo "started $*"; exec sleep 30'));
    await caddy.start();
    await until(() => lines.isNotEmpty);
    expect(lines.first, 'caddy: started run --config /etc/caddy/Caddyfile --adapter caddyfile');
    final stopping = Stopwatch()..start();
    await caddy.stop();
    expect(stopping.elapsed, lessThan(const Duration(seconds: 5)));
    expect(caddy.restarts, 0);
  });

  test('a Caddy that exits while starting is a configuration problem, not something to retry', () async {
    final caddy = supervise(standIn('caddy', 'echo "bad Caddyfile" >&2; exit 1'));
    await expectLater(caddy.start(), throwsA(isA<CaddyStartException>().having((e) => e.message, 'message', contains('code 1'))));
    await until(() => lines.contains('caddy: bad Caddyfile'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(caddy.restarts, 0);
  });

  test('a Caddy that exits after starting is started again', () async {
    final count = '${dir.path}/starts';
    final caddy = supervise(standIn('caddy', 'echo run >> $count; sleep 0.3; exit 2'), grace: const Duration(milliseconds: 100));
    await caddy.start();
    // A run has started once it has written its line. Stopping as soon as the
    // supervisor counts the restart can kill the third run before it does.
    await until(() => File(count).existsSync() && File(count).readAsLinesSync().length >= 3);
    await caddy.stop();
    expect(caddy.restarts, greaterThanOrEqualTo(2));
    expect(lines, contains(startsWith('clide_broker: Caddy exited with code 2; starting it again in 20 ms')));
  });

  test('waits longer after each exit, from the start again once a run was steady', () async {
    final waits = <int>[];
    final caddy = supervise(
      standIn('caddy', 'sleep 0.2; exit 3'),
      grace: const Duration(milliseconds: 100),
      backoff: (attempt) {
        waits.add(attempt);
        return const Duration(milliseconds: 10);
      },
    );
    await caddy.start();
    await until(() => waits.length >= 3);
    await caddy.stop();
    expect(waits.take(3), [0, 1, 2]);
  });

  test('a restart that is still waiting does not happen after stop', () async {
    final count = '${dir.path}/starts';
    final caddy = supervise(
      standIn('caddy', 'echo run >> $count; sleep 0.2; exit 2'),
      grace: const Duration(milliseconds: 100),
      backoff: (_) => const Duration(milliseconds: 400),
    );
    await caddy.start();
    await until(() => lines.any((l) => l.contains('starting it again')));
    await caddy.stop();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(File(count).readAsLinesSync(), hasLength(1));
  });

  test('stop ends a Caddy that ignores SIGTERM with SIGKILL', () async {
    final caddy = supervise(standIn('caddy', "trap '' TERM; echo up; while true; do sleep 0.1; done"));
    await caddy.start();
    final stopping = Stopwatch()..start();
    await caddy.stop(grace: const Duration(milliseconds: 300));
    expect(stopping.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('stop before start does nothing', () async {
    await supervise('/bin/true').stop();
  });
}
