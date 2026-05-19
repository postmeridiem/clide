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
    final build = await Process.run('cc', [
      '-std=c99',
      '-O2',
      '-Wall',
      src,
      '-o',
      out,
    ]);
    expect(build.exitCode, 0, reason: 'cc failed: ${build.stderr}');
    binaryPath = out;

    // Synthetic git workspace — the C client walks up looking for
    // `.git`, hashes whatever it lands on, and connects to the
    // matching socket. Match it by handing the same root to the
    // server.
    workspaceRoot = Directory.systemTemp.createTempSync('clide-ws-');
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

  Future<ProcessResult> runCli(List<String> argv) {
    return Process.run(binaryPath, argv, workingDirectory: workspaceRoot.path);
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
      final r = await Process.run(binaryPath, ['status'], workingDirectory: outside.path);
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
      final proc = await Process.start(binaryPath, ['tail', '--events', '--filter', 'pane'], workingDirectory: workspaceRoot.path);
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
  });
}
