/// NativePty smoke tests.
///
/// Exercises forkpty() end-to-end: spawn → child output through the
/// reader isolate. Linux + macOS only; skipped elsewhere.
///
/// Tagged `forkpty` — must run via `dart test`, not `flutter test`.
/// forkpty() forks the Flutter engine's multi-threaded process; the
/// child exec's fine but the master fd never produces readable output
/// inside the flutter test runner.
@Tags(['forkpty'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

    test('write sends keystrokes to child', () async {
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

    test('non-existent workingDirectory produces the chdir-failed diagnostic', () async {
      // chdir() fails in the child → writes diagnostic + _exit(1).
      final s = NativePty.start(
        executable: '/bin/sh',
        arguments: ['-c', 'echo should-not-run'],
        columns: 80,
        rows: 24,
        workingDirectory: '/tmp/clide-no-such-dir-${DateTime.now().microsecondsSinceEpoch}',
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
      expect(buf.toString(), contains('chdir failed'));
    });

    test('non-existent executable produces the exec-failed diagnostic', () async {
      final s = NativePty.start(
        executable: '/tmp/clide-no-such-binary-${DateTime.now().microsecondsSinceEpoch}',
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
      final buf = StringBuffer();
      final done = Completer<void>();
      s.output.listen(
        (b) => buf.write(utf8.decode(b, allowMalformed: true)),
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      expect(buf.toString(), contains('exec failed'));
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
