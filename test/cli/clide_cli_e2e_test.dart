/// End-to-end test for the C `clide` shell client (T-126).
///
/// Compiles native/clide-cli/clide.c via the host `cc` (skip if not
/// available), starts an IpcServer with a controlled workspace root,
/// and exercises the client as a child process. Verifies the
/// cross-language FNV-1a hash agreement: if the C binary and the
/// Dart server compute the same socket path for the same workspace,
/// the round-trip works; if not, the connect fails.
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/src/cli/argv_dispatch.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/daemon/instance_command.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/server.dart';
import 'package:test/test.dart';

void main() {
  // Build the binary once for the whole suite.
  late final String binaryPath;
  late final bool hasCC;
  late final Directory workspaceRoot;
  late final IpcServer server;
  late final DaemonDispatcher dispatcher;
  late final DaemonBus streamingBus;

  setUpAll(() async {
    final repoRoot = Directory.current.path;
    final ccProbe = await Process.run('sh', ['-c', 'command -v cc']);
    hasCC = ccProbe.exitCode == 0;
    if (!hasCC) return;
    final src = '$repoRoot/native/clide-cli/clide.c';
    final out = '${Directory.systemTemp.createTempSync('clide-cli-test-').path}/clide';
    final build = await Process.run('cc', ['-std=c99', '-O2', '-Wall', src, '-o', out]);
    expect(build.exitCode, 0, reason: 'cc failed: ${build.stderr}');
    binaryPath = out;

    // Synthetic git workspace — the C client walks up looking for
    // `.git`, hashes whatever it lands on, and connects to the
    // matching socket. Match it by handing the same root to the
    // server. Canonicalise: the client resolves its CWD via the OS
    // (getcwd), so on macOS it hashes /private/tmp/… while a raw
    // createTemp path is /tmp/… — the two hashes must agree.
    workspaceRoot = Directory(Directory.systemTemp.createTempSync('clide-ws-').resolveSymbolicLinksSync());
    Directory('${workspaceRoot.path}/.git').createSync();
    dispatcher = DaemonDispatcher();
    registerArgvUnwrap(dispatcher);
    streamingBus = DaemonBus();
    server = IpcServer(
      dispatcher: dispatcher,
      workspaceRoot: workspaceRoot.path,
      log: Logger(minLevel: LogLevel.error, sinks: const []),
      events: streamingBus,
    );
    await server.start();
    // The `instance` command isn't a dispatcher builtin (main.dart registers it
    // with the live workspace/pid); register it here so `clide instances` has
    // identity to read back (T-247).
    registerInstanceCommand(dispatcher, version: '9.9.9-test', pid: 4242, workspace: workspaceRoot.path, socketPath: server.socketPath);
  });

  tearDownAll(() async {
    if (!hasCC) return;
    try {
      await server.stop();
    } catch (_) {}
    await streamingBus.dispose();
    if (workspaceRoot.existsSync()) {
      workspaceRoot.deleteSync(recursive: true);
    }
  });

  // Clear any inherited CLIDE_SOCK so these tests exercise workspace discovery
  // hermetically — the suite may run *inside* a clide instance, which exports
  // CLIDE_SOCK to child processes (T-247). Empty string reads as unset to the
  // client, which then falls back to per-workspace discovery.
  Future<ProcessResult> runCli(List<String> argv) {
    return Process.run(binaryPath, argv, workingDirectory: workspaceRoot.path, environment: const {'CLIDE_SOCK': ''});
  }

  group('clide-cli (T-126)', () {
    test('no args → EX_USAGE (64) with a usage banner on stderr', () async {
      if (!hasCC) {
        markTestSkipped('cc not available');
        return;
      }
      final r = await runCli(const []);
      expect(r.exitCode, 64);
      expect(r.stderr.toString(), contains('usage'));
    });

    test('outside a git repo → EX_USAGE', () async {
      if (!hasCC) {
        markTestSkipped('cc not available');
        return;
      }
      final outside = Directory.systemTemp.createTempSync('clide-no-git-');
      addTearDown(() => outside.deleteSync(recursive: true));
      final r = await Process.run(binaryPath, ['status'], workingDirectory: outside.path, environment: const {'CLIDE_SOCK': ''});
      expect(r.exitCode, 64);
      expect(r.stderr.toString(), contains('git repository'));
    });

    test('ping returns ok JSON on stdout, exit 0', () async {
      if (!hasCC) {
        markTestSkipped('cc not available');
        return;
      }
      final r = await runCli(['ping']);
      expect(r.exitCode, 0, reason: 'stderr: ${r.stderr}');
      final data = jsonDecode(r.stdout.toString().trim()) as Map<String, Object?>;
      expect(data['pong'], isTrue);
    });

    test('subsystem.verb routing through the dispatcher', () async {
      if (!hasCC) {
        markTestSkipped('cc not available');
        return;
      }
      // Stub handler that echoes the request's args back so we can
      // verify the wire shape end-to-end.
      dispatcher.register('probe.echo', (req) async => IpcResponse.ok(id: req.id, data: req.args));
      final r = await runCli(['probe', 'echo', 'first', '--flag=val', '--bool', '--', 'pass1']);
      expect(r.exitCode, 0, reason: 'stderr: ${r.stderr}');
      final data = jsonDecode(r.stdout.toString().trim()) as Map<String, Object?>;
      expect(data['positional'], ['first']);
      expect((data['flags'] as Map)['flag'], 'val');
      expect((data['flags'] as Map)['bool'], isTrue);
      expect(data['passthrough'], ['pass1']);
    });

    test('unknown verb → notFound exit code', () async {
      if (!hasCC) {
        markTestSkipped('cc not available');
        return;
      }
      final r = await runCli(['nosuchsub', 'nosuchverb']);
      expect(r.exitCode, isNot(0));
      expect(r.stderr.toString(), isNotEmpty);
    });

    test('tail --events streams bus events to stdout (T-129)', () async {
      if (!hasCC) {
        markTestSkipped('cc not available');
        return;
      }
      final proc = await Process.start(
        binaryPath,
        ['tail', '--events', '--filter', 'pane'],
        workingDirectory: workspaceRoot.path,
        environment: const {'CLIDE_SOCK': ''},
      );
      addTearDown(() => proc.kill());
      final lines = <String>[];
      final sub = proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(lines.add);
      addTearDown(sub.cancel);
      // Wait for the ack so the server has registered us.
      var attempts = 0;
      while (lines.isEmpty && attempts < 50) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        attempts++;
      }
      expect(lines, isNotEmpty, reason: 'no ack received');
      // Emit two events.
      streamingBus.emit(DaemonEvent(subsystem: 'pane', kind: 'spawned', data: const {'id': 'p1'}, ts: DateTime.now().toUtc()));
      streamingBus.emit(DaemonEvent(subsystem: 'pane', kind: 'closed', data: const {'id': 'p1'}, ts: DateTime.now().toUtc()));
      attempts = 0;
      while (lines.length < 3 && attempts < 100) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        attempts++;
      }
      expect(lines.length, greaterThanOrEqualTo(3), reason: 'expected ack + 2 events, got: $lines');
      final concatenated = lines.skip(1).join('\n');
      expect(concatenated, contains('"kind":"spawned"'));
      expect(concatenated, contains('"kind":"closed"'));
    });

    test('CLIDE_SOCK pins to that instance, beating workspace discovery (T-247)', () async {
      if (!hasCC) {
        markTestSkipped('cc not available');
        return;
      }
      // From a NON-git dir (where discovery would fail), an explicit CLIDE_SOCK
      // still connects — it's the explicit target.
      final outside = Directory.systemTemp.createTempSync('clide-sock-');
      addTearDown(() => outside.deleteSync(recursive: true));
      final r = await Process.run(binaryPath, ['ping'], workingDirectory: outside.path, environment: {'CLIDE_SOCK': server.socketPath});
      expect(r.exitCode, 0, reason: 'stderr: ${r.stderr}');
      expect((jsonDecode(r.stdout.toString().trim()) as Map)['pong'], isTrue);
    });

    test('a dead CLIDE_SOCK fails loudly, never falling back to discovery (T-247)', () async {
      if (!hasCC) {
        markTestSkipped('cc not available');
        return;
      }
      // Run from the REAL workspace — discovery WOULD succeed — to prove the
      // bogus explicit target aborts instead of silently hitting another instance.
      final bogus = '${workspaceRoot.path}/DOES_NOT_EXIST.sock';
      final r = await Process.run(binaryPath, ['ping'], workingDirectory: workspaceRoot.path, environment: {'CLIDE_SOCK': bogus});
      expect(r.exitCode, isNot(0));
      expect(r.stderr.toString(), contains('cannot connect'));
      expect(r.stdout.toString().trim(), isEmpty, reason: 'must not return data from a different instance');
    });

    test('an instance that accepts but never answers times out instead of hanging (T-542)', () async {
      if (!hasCC) {
        markTestSkipped('cc not available');
        return;
      }
      // The failure this guards is worse than a crash. `connect()` succeeds
      // against a wedged instance, the request is accepted, and the response
      // never comes — so every verb blocked forever, with no output and no exit
      // code. An agent or script driving `clide` had nothing to react to.
      final wedgedPath = '${workspaceRoot.path}/wedged.sock';
      final wedged = await ServerSocket.bind(InternetAddress(wedgedPath, type: InternetAddressType.unix), 0);
      // Accept connections and deliberately never reply.
      final accepted = <Socket>[];
      wedged.listen(accepted.add);
      addTearDown(() async {
        for (final s in accepted) {
          s.destroy();
        }
        await wedged.close();
        final f = File(wedgedPath);
        if (f.existsSync()) f.deleteSync();
      });

      final sw = Stopwatch()..start();
      final r = await Process.run(
        binaryPath,
        ['ping'],
        workingDirectory: workspaceRoot.path,
        // Short deadline so the test asserts the mechanism, not the shipped
        // 30s default — which is deliberately generous because a deadline
        // cannot tell a wedged instance from a slow answer.
        environment: {'CLIDE_SOCK': wedgedPath, 'CLIDE_TIMEOUT_MS': '750'},
      );
      sw.stop();

      expect(r.exitCode, isNot(0), reason: 'stdout: ${r.stdout}');
      expect(sw.elapsed, lessThan(const Duration(seconds: 15)), reason: 'the CLI blocked instead of giving up');
      expect(r.stderr.toString(), contains('did not answer'), reason: 'the message must say what happened: ${r.stderr}');
      expect(r.stdout.toString().trim(), isEmpty);
    });

    test('instances skips a wedged instance rather than blocking on it (T-542)', () async {
      if (!hasCC) {
        markTestSkipped('cc not available');
        return;
      }
      // `instances` exists to find the live ones; an instance that cannot answer
      // is exactly what the caller is trying to see past, so it must cost a
      // moment and not the whole command.
      // Beside the real one, so discovery enumerates both.
      final wedgedPath = '${File(server.socketPath).parent.path}/wedged.sock';
      final wedged = await ServerSocket.bind(InternetAddress(wedgedPath, type: InternetAddressType.unix), 0);
      final accepted = <Socket>[];
      wedged.listen(accepted.add);
      addTearDown(() async {
        for (final s in accepted) {
          s.destroy();
        }
        await wedged.close();
        final f = File(wedgedPath);
        if (f.existsSync()) f.deleteSync();
      });

      final sw = Stopwatch()..start();
      final r = await Process.run(binaryPath, ['instances'], workingDirectory: workspaceRoot.path, environment: const {'CLIDE_SOCK': ''});
      sw.stop();

      expect(r.exitCode, 0, reason: 'stderr: ${r.stderr}');
      expect(sw.elapsed, lessThan(const Duration(seconds: 20)), reason: 'a wedged peer blocked the whole enumeration');
      expect(r.stdout.toString(), contains(server.socketPath), reason: 'the live instance must still be listed');
    });

    test('instances lists live instances with their identity (T-247)', () async {
      if (!hasCC) {
        markTestSkipped('cc not available');
        return;
      }
      final r = await Process.run(binaryPath, ['instances'], workingDirectory: workspaceRoot.path, environment: const {'CLIDE_SOCK': ''});
      expect(r.exitCode, 0, reason: 'stderr: ${r.stderr}');
      // This test server is one live instance; its socket path must appear.
      // Other live clides on the machine may also be listed — assert ours is
      // present and carries the full identity payload, not an exact count.
      final lines = const LineSplitter().convert(r.stdout.toString());
      final mine = lines.where((l) => l.contains(server.socketPath)).toList();
      expect(mine, hasLength(1), reason: 'expected exactly one line for our socket, got: $lines');
      final obj = jsonDecode(mine.single) as Map<String, Object?>;
      expect(obj['workspace'], workspaceRoot.path);
      expect(obj['version'], '9.9.9-test');
      expect(obj['pid'], 4242);
      expect(obj['socketPath'], server.socketPath);
    });
  });
}
