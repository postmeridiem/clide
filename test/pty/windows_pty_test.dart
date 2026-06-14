/// WindowsPty (ConPTY) smoke tests — the Windows sibling of
/// `session_test.dart`. Windows only; skipped elsewhere.
///
/// Same `tags: ['pty']` discipline as the POSIX suite: tests that
/// depend on the reader isolate delivering ConPTY output run serially
/// via `dart test` per `ci/test.sh`; only the synchronous-throw test
/// stays untagged.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/pty/errors.dart';
import 'package:clide/src/pty/windows_pty.dart';
import 'package:test/test.dart';

import '../helpers/timeouts.dart';

void main() {
  if (!Platform.isWindows) return;

  group('WindowsPty', () {
    test('spawns cmd /c echo and reads output', tags: ['pty'], () async {
      final s = WindowsPty.start(
        executable: 'cmd.exe',
        arguments: ['/c', 'echo hello-pty'],
        columns: 80,
        rows: 24,
        environment: {...Platform.environment, 'TERM': 'xterm-256color'},
      );
      addTearDown(s.close);

      final got = await _readUntil(s, 'hello-pty', ioTimeout);
      expect(got, contains('hello-pty'));
    });

    test('write sends keystrokes to child', tags: ['pty'], () async {
      final s = WindowsPty.start(executable: 'cmd.exe', arguments: [], columns: 80, rows: 24, environment: {...Platform.environment, 'TERM': 'xterm-256color'});
      addTearDown(s.close);

      final buf = StringBuffer();
      final firstByte = Completer<void>();
      final sub = s.output.listen((bytes) {
        buf.write(utf8.decode(bytes, allowMalformed: true));
        if (!firstByte.isCompleted) firstByte.complete();
      });
      addTearDown(sub.cancel);

      await firstByte.future.timeout(ioTimeout, onTimeout: () => fail('shell never produced its first byte within ${ioTimeout.inSeconds}s'));

      s.write(utf8.encode('echo write-test-ok\r\n'));

      final result = await _waitForBuffer(buf, 'write-test-ok', ioTimeout);
      expect(result, contains('write-test-ok'));
    });

    test('child exit closes the output stream without close()', tags: ['pty'], () async {
      // The waiter isolate must ClosePseudoConsole on child exit, or the
      // reader blocks forever and pane.exit never fires.
      final s = WindowsPty.start(executable: 'cmd.exe', arguments: ['/c', 'echo bye'], columns: 80, rows: 24, environment: {...Platform.environment});
      addTearDown(s.close);

      final done = Completer<void>();
      s.output.listen((_) {}, onDone: () => done.complete());
      await done.future.timeout(ioTimeout, onTimeout: () => fail('output stream did not close within ${ioTimeout.inSeconds}s of child exit'));
      expect(s.isClosed, isTrue);
    });

    test('close kills child and closes output', tags: ['pty'], () async {
      final s = WindowsPty.start(executable: 'cmd.exe', arguments: [], columns: 80, rows: 24, environment: {...Platform.environment});

      final done = Completer<void>();
      s.output.listen((_) {}, onDone: () => done.complete());

      await s.close();
      await done.future.timeout(ioTimeout, onTimeout: () => fail('output stream did not close within ${ioTimeout.inSeconds}s after s.close()'));
      expect(s.isClosed, isTrue);
    });

    test('bare command name resolves via PATH + PATHEXT', tags: ['pty'], () async {
      // 'cmd' is bare and extension-less; resolution must find cmd.exe.
      final s = WindowsPty.start(
        executable: 'cmd',
        arguments: ['/c', 'echo path-resolution-ok'],
        columns: 80,
        rows: 24,
        environment: {...Platform.environment},
      );
      addTearDown(s.close);

      final got = await _readUntil(s, 'path-resolution-ok', ioTimeout);
      expect(got, contains('path-resolution-ok'));
    });

    test('resize survives a live session', tags: ['pty'], () async {
      final s = WindowsPty.start(executable: 'cmd.exe', arguments: [], columns: 80, rows: 24, environment: {...Platform.environment});
      addTearDown(s.close);
      s.resize(cols: 120, rows: 40);
      expect(s.isClosed, isFalse);
    });

    test('non-existent executable surfaces a PtyException at spawn time', () {
      // CreateProcessW fails with ERROR_FILE_NOT_FOUND (2) — same code
      // POSIX ENOENT happens to use, but asserted independently here.
      expect(
        () => WindowsPty.start(
          executable: 'C:\\clide-no-such-binary-${DateTime.now().microsecondsSinceEpoch}.exe',
          arguments: const [],
          columns: 80,
          rows: 24,
          environment: {...Platform.environment},
        ),
        throwsA(isA<PtyException>().having((e) => e.errno, 'errno', 2)),
      );
    });
  });
}

/// Collect output until [needle] appears or [limit] elapses.
Future<String> _readUntil(WindowsPty s, String needle, Duration limit) async {
  final buf = StringBuffer();
  final found = Completer<String>();
  final sub = s.output.listen(
    (bytes) {
      buf.write(utf8.decode(bytes, allowMalformed: true));
      if (!found.isCompleted && buf.toString().contains(needle)) {
        found.complete(buf.toString());
      }
    },
    onDone: () {
      if (!found.isCompleted) found.complete(buf.toString());
    },
  );
  try {
    return await found.future.timeout(limit, onTimeout: () => buf.toString());
  } finally {
    await sub.cancel();
  }
}

/// Poll [buf] until it contains [needle] or [limit] elapses.
Future<String> _waitForBuffer(StringBuffer buf, String needle, Duration limit) async {
  final deadline = DateTime.now().add(limit);
  while (DateTime.now().isBefore(deadline)) {
    if (buf.toString().contains(needle)) return buf.toString();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return buf.toString();
}
