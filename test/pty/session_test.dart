/// NativePty smoke tests.
///
/// Exercises posix_spawn() end-to-end: spawn → child output through the
/// reader isolate. Linux + macOS only; skipped elsewhere.
///
/// Per-test `tags: ['forkpty']` marks the tests that need `dart test`
/// rather than the flutter test runner — currently just the
/// write/read-back bidirectional test (writes to the master fd never
/// reach the child under the flutter test runner; reads work fine).
/// Everything else runs under `flutter test` and contributes to
/// coverage.
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
    test('spawns shell -c echo and reads output', () async {
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

      final buf = StringBuffer();
      final done = Completer<void>();
      s.output.listen(
        (bytes) => buf.write(utf8.decode(bytes, allowMalformed: true)),
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );

      await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      expect(buf.toString(), contains('hello-pty'));
    });

    test('write sends keystrokes to child', tags: ['forkpty'], () async {
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
      s.output.listen((bytes) => buf.write(utf8.decode(bytes, allowMalformed: true)));

      await Future<void>.delayed(const Duration(milliseconds: 500));

      s.write(utf8.encode('echo write-test-ok\n'));

      for (var i = 0; i < 50 && !buf.toString().contains('write-test-ok'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(buf.toString(), contains('write-test-ok'));
    });

    test('close kills child and closes output', () async {
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
      await done.future.timeout(const Duration(seconds: 3));
      expect(s.isClosed, isTrue);
    });

    test('bare command name resolves via the PATH env var', () async {
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
      final buf = StringBuffer();
      final done = Completer<void>();
      s.output.listen(
        (b) => buf.write(utf8.decode(b, allowMalformed: true)),
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      expect(buf.toString(), contains('path-resolution-ok'));
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
