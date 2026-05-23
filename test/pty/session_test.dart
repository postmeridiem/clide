/// NativePty smoke tests.
///
/// Exercises posix_spawn() end-to-end: spawn → child output through the
/// reader isolate. Linux + macOS only; skipped elsewhere.
///
/// Per-test `tags: ['pty']` marks the tests that depend on the
/// reader isolate delivering output from the master fd — reads from a
/// pty master under the flutter test runner are unstable when other
/// suites run in parallel (intermittently empty). Only the
/// synchronous-throw and resize tests stay untagged so they
/// contribute to coverage under `flutter test`. The output-dependent
/// tests run via `dart test` per `ci/test.sh`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/pty/errors.dart';
import 'package:clide/src/pty/native_pty.dart';
import 'package:test/test.dart';

void main() {
  if (!Platform.isLinux && !Platform.isMacOS) return;

  group('NativePty', () {
    test('spawns shell -c echo and reads output', tags: ['pty'], retry: 2, () async {
      final s = NativePty.start(
        executable: '/bin/sh',
        arguments: ['-c', 'echo hello-pty'],
        columns: 80,
        rows: 24,
        workingDirectory: '/',
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
        },
      );
      addTearDown(s.close);

      final got = await _readUntil(s, 'hello-pty', const Duration(seconds: 20));
      expect(got, contains('hello-pty'));
    });

    test('write sends keystrokes to child', tags: ['pty'], retry: 2, () async {
      final s = NativePty.start(
        executable: '/bin/sh',
        arguments: [],
        columns: 80,
        rows: 24,
        workingDirectory: '/',
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
        },
      );
      addTearDown(s.close);

      final buf = StringBuffer();
      final firstByte = Completer<void>();
      final sub = s.output.listen((bytes) {
        buf.write(utf8.decode(bytes, allowMalformed: true));
        // First byte from the pty signals the shell is up and the
        // reader isolate is delivering — better than a fixed sleep.
        if (!firstByte.isCompleted) firstByte.complete();
      });
      addTearDown(sub.cancel);

      await firstByte.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => fail('shell never produced its first byte within 20s'),
      );

      s.write(utf8.encode('echo write-test-ok\n'));

      final result = await _waitForBuffer(buf, 'write-test-ok', const Duration(seconds: 20));
      expect(result, contains('write-test-ok'));
    });

    test('close kills child and closes output', tags: ['pty'], retry: 2, () async {
      final s = NativePty.start(
        executable: '/bin/sh',
        arguments: [],
        columns: 80,
        rows: 24,
        workingDirectory: '/',
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
        },
      );

      final done = Completer<void>();
      s.output.listen((_) {}, onDone: () => done.complete());

      await s.close();
      await done.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => fail('output stream did not close within 10s after s.close()'),
      );
      expect(s.isClosed, isTrue);
    });

    test('bare command name resolves via the PATH env var', tags: ['pty'], retry: 2, () async {
      // 'sh' is a bare command; without resolution, execve would fail.
      final s = NativePty.start(
        executable: 'sh',
        arguments: ['-c', 'echo path-resolution-ok'],
        columns: 80,
        rows: 24,
        workingDirectory: '/',
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
        },
      );
      addTearDown(s.close);

      final got = await _readUntil(s, 'path-resolution-ok', const Duration(seconds: 20));
      expect(got, contains('path-resolution-ok'));
    });

    test('non-existent workingDirectory surfaces a PtyException at spawn time', () {
      // posix_spawn returns ENOENT (errno 2) when the file_actions chdir
      // step finds the directory missing — propagates as a thrown
      // PtyException, not a child-side diagnostic on the pty.
      expect(
        () => NativePty.start(
          executable: '/bin/sh',
          arguments: ['-c', 'echo should-not-run'],
          columns: 80,
          rows: 24,
          workingDirectory: '/tmp/clide-no-such-dir-${DateTime.now().microsecondsSinceEpoch}',
          environment: {
            ...Platform.environment,
            'TERM': 'xterm-256color',
          },
        ),
        throwsA(isA<PtyException>().having((e) => e.errno, 'errno', 2)),
      );
    });

    test('non-existent executable surfaces a PtyException at spawn time', () {
      // posix_spawn surfaces exec-time errors as a non-zero return on
      // glibc (which uses vfork — the child is suspended until execve
      // either succeeds or fails). ENOENT (errno 2) for missing binary.
      expect(
        () => NativePty.start(
          executable: '/tmp/clide-no-such-binary-${DateTime.now().microsecondsSinceEpoch}',
          arguments: const [],
          columns: 80,
          rows: 24,
          workingDirectory: '/',
          environment: {
            ...Platform.environment,
            'TERM': 'xterm-256color',
          },
        ),
        throwsA(isA<PtyException>().having((e) => e.errno, 'errno', 2)),
      );
    });

    test('start with a bare command name resolves it via PATH (no read)', () async {
      // Resolves "cat" to /bin/cat (or wherever it lives on PATH).
      // Doesn't read the master fd — that path is exercised by the
      // pty-tagged version of this test under `dart test`.
      final s = NativePty.start(
        executable: 'cat',
        arguments: const [],
        columns: 80,
        rows: 24,
        workingDirectory: '/',
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
        },
      );
      addTearDown(s.close);
      expect(s.pid, greaterThan(0));
    });

    test('resize on a live PTY does not throw', () async {
      final s = NativePty.start(
        executable: '/bin/sh',
        arguments: ['-c', 'sleep 0.5'],
        columns: 80,
        rows: 24,
        workingDirectory: '/',
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
        },
      );
      addTearDown(s.close);
      s.resize(cols: 120, rows: 30);
    });
  });
}

// -- Helpers ----------------------------------------------------------------

/// Read bytes from [s] into a local buffer until [marker] appears or
/// [timeout] elapses. Fails the test on timeout — the previous bare
/// `onTimeout: () {}` pattern hid the real failure mode (reader
/// isolate never delivered) behind a confusing "buffer empty"
/// assertion.
Future<String> _readUntil(NativePty s, String marker, Duration timeout) async {
  final buf = StringBuffer();
  final done = Completer<String>();
  final sub = s.output.listen(
    (bytes) {
      buf.write(utf8.decode(bytes, allowMalformed: true));
      if (buf.toString().contains(marker) && !done.isCompleted) {
        done.complete(buf.toString());
      }
    },
    onDone: () {
      if (!done.isCompleted) done.complete(buf.toString());
    },
  );
  try {
    return await done.future.timeout(
      timeout,
      onTimeout: () => fail('pty did not produce "$marker" within ${timeout.inSeconds}s (buffer: "${buf.toString().replaceAll('\n', r'\n')}")'),
    );
  } finally {
    await sub.cancel();
  }
}

/// Poll [buf] until [marker] appears or [timeout] elapses. Used after
/// a write — the bytes flow back through the same output stream a
/// caller is already listening to, so we just watch the buffer.
Future<String> _waitForBuffer(StringBuffer buf, String marker, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (!buf.toString().contains(marker)) {
    if (DateTime.now().isAfter(deadline)) {
      fail('buffer never contained "$marker" within ${timeout.inSeconds}s (buffer: "${buf.toString().replaceAll('\n', r'\n')}")');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  return buf.toString();
}
