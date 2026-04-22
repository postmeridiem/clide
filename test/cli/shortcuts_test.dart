/// End-to-end tests for the tier-2 CLI shortcuts.
///
/// Each test launches `bin/clide --daemon` as a subprocess, exercises
/// a shortcut (`open`, `active`, `insert`, `save`, `tail`), and
/// asserts the JSON response shape. Requires a built `bin/clide`
/// binary — `ci/test_core.sh` runs `make build` first when needed,
/// or here we build on demand.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const _socketEnv = 'CLIDE_SOCKET_PATH';

void main() {
  late Directory sandbox;
  late Process daemon;
  late String socketPath;
  late String clideBin;

  setUpAll(() async {
    final candidate = File('bin/clide');
    if (!candidate.existsSync()) {
      final built = await Process.run('make', const ['build']);
      if (built.exitCode != 0) {
        throw StateError('make build failed: ${built.stderr}');
      }
    }
    clideBin = candidate.absolute.path;
  });

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('clide-cli-t2-');
    await File('${sandbox.path}/doc.md').writeAsString('alpha beta');
    // Each test gets its own socket path so concurrent test runs don't
    // collide. Passed through the daemon via env.
    socketPath = '${sandbox.path}/daemon.sock';
    daemon = await Process.start(
      clideBin,
      const ['--daemon'],
      workingDirectory: sandbox.path,
      environment: {
        ...Platform.environment,
        _socketEnv: socketPath,
      },
    );
    // Wait for the "listening" line on stderr so we know it's ready.
    final ready = Completer<void>();
    daemon.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (!ready.isCompleted && line.contains('listening')) {
        ready.complete();
      }
    });
    await ready.future.timeout(const Duration(seconds: 5));
  });

  tearDown(() async {
    daemon.kill(ProcessSignal.sigterm);
    await daemon.exitCode.timeout(const Duration(seconds: 3),
        onTimeout: () {
      daemon.kill(ProcessSignal.sigkill);
      return -1;
    });
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<Map<String, Object?>> run(List<String> args) async {
    final r = await Process.run(
      clideBin,
      args,
      workingDirectory: sandbox.path,
      environment: {
        ...Platform.environment,
        _socketEnv: socketPath,
      },
    );
    expect(r.exitCode, 0, reason: 'stderr: ${r.stderr}');
    return jsonDecode(r.stdout.toString().trim()) as Map<String, Object?>;
  }

  test('clide open <path> returns buffer metadata', () async {
    final r = await run(['open', 'doc.md']);
    expect(r['id'], startsWith('b_'));
    expect(r['path'], 'doc.md');
  });

  test('clide active reflects the most recent open', () async {
    await run(['open', 'doc.md']);
    final r = await run(['active']);
    final active = r['active']! as Map;
    expect(active['path'], 'doc.md');
  });

  test('clide insert + clide active round-trip', () async {
    await run(['open', 'doc.md']);
    await run(['insert', 'hello ']);
    final r = await run(['active']);
    final active = r['active']! as Map;
    expect(active['dirty'], isTrue);
    expect((active['length'] as num).toInt(), greaterThan('alpha beta'.length));
  });

  test('clide save clears dirty + writes to disk', () async {
    await run(['open', 'doc.md']);
    await run(['insert', 'X ']);
    await run(['save']);
    final active = (await run(['active']))['active']! as Map;
    expect(active['dirty'], isFalse);
    final disk = await File('${sandbox.path}/doc.md').readAsString();
    expect(disk.startsWith('X '), isTrue);
  });

  test('clide tail --events streams editor.* events', () async {
    // Start a tail subscriber.
    final tail = await Process.start(
      clideBin,
      const ['tail', '--events', '--filter', 'editor'],
      workingDirectory: sandbox.path,
      environment: {
        ...Platform.environment,
        _socketEnv: socketPath,
      },
    );

    final received = <Map<String, Object?>>[];
    final sub = tail.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.isEmpty) return;
      received.add(jsonDecode(line) as Map<String, Object?>);
    });

    // Give the subscriber a beat to connect.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    await run(['open', 'doc.md']);
    await run(['insert', 'T ']);

    // Wait up to 2s for events.
    for (var i = 0; i < 20 && received.length < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    tail.kill(ProcessSignal.sigint);
    await tail.exitCode.timeout(const Duration(seconds: 2),
        onTimeout: () {
      tail.kill(ProcessSignal.sigkill);
      return -1;
    });
    await sub.cancel();

    final kinds = received.map((e) => e['kind']).toList();
    expect(kinds, containsAll(['editor.opened', 'editor.edited']));
    // Confirm filter actually filtered — no pane events made it in.
    for (final e in received) {
      expect(e['subsystem'], 'editor');
    }
  });
}
