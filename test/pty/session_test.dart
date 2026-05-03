/// NativePty smoke tests.
///
/// Exercises forkpty() end-to-end: spawn → child output through the
/// reader isolate. Linux + macOS only; skipped elsewhere.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/pty/native_pty.dart';
import 'package:test/test.dart';

void main() {
  if (!Platform.isLinux && !Platform.isMacOS) return;

  final shell = Platform.environment['SHELL'] ?? '/bin/zsh';

  group('NativePty', () {
    test('spawns shell -c echo and reads output', () async {
      final s = NativePty.start(
        executable: shell,
        arguments: ['-l', '-c', 'echo hello-pty'],
        columns: 80,
        rows: 24,
        workingDirectory: Platform.environment['HOME'] ?? '/',
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
        },
      );
      addTearDown(s.close);

      final buf = StringBuffer();
      s.output.listen((bytes) => buf.write(utf8.decode(bytes, allowMalformed: true)));

      // Shell exits quickly; give reader up to 3s.
      for (var i = 0; i < 30 && !buf.toString().contains('hello-pty'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(buf.toString(), contains('hello-pty'));
    });

    test('write sends keystrokes to child', () async {
      final s = NativePty.start(
        executable: shell,
        arguments: ['-l'],
        columns: 80,
        rows: 24,
        workingDirectory: Platform.environment['HOME'] ?? '/',
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
        },
      );
      addTearDown(s.close);

      final buf = StringBuffer();
      s.output.listen((bytes) => buf.write(utf8.decode(bytes, allowMalformed: true)));

      // Wait for prompt.
      await Future<void>.delayed(const Duration(seconds: 1));

      // Type a command.
      s.write(utf8.encode('echo write-test-ok\n'));

      for (var i = 0; i < 30 && !buf.toString().contains('write-test-ok'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(buf.toString(), contains('write-test-ok'));
    });

    test('close kills child and closes output', () async {
      final s = NativePty.start(
        executable: shell,
        arguments: ['-l'],
        columns: 80,
        rows: 24,
        workingDirectory: Platform.environment['HOME'] ?? '/',
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
