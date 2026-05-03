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
  });
}
