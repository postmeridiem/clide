/// Unit tests for `lib/src/pty/env.dart` and
/// `lib/src/pty/errors.dart`.
library;

import 'dart:io';

import 'package:clide/src/pty/env.dart';
import 'package:clide/src/pty/errors.dart';
import 'package:test/test.dart';

void main() {
  group('PtyException', () {
    test('toString includes the op + message', () {
      const e = PtyException('posix_spawn', 'kaboom');
      expect(e.toString(), contains('posix_spawn'));
      expect(e.toString(), contains('kaboom'));
      expect(e.toString(), isNot(contains('errno=')));
    });

    test('toString embeds errno when present', () {
      const e = PtyException('execve', 'no such file', errno: 2);
      expect(e.toString(), contains('errno=2'));
    });
  });

  group('expandedPath', () {
    test('returns a non-empty string on every platform', () {
      expect(expandedPath, isNotEmpty);
    });

    test('on Linux/Windows, equals Platform.environment[PATH]', () {
      if (Platform.isMacOS) return; // macOS path-merge tested separately.
      expect(expandedPath, Platform.environment['PATH']);
    });

    test('on macOS, includes the well-known extras', () {
      if (!Platform.isMacOS) return;
      // Homebrew is the canonical one; at least one of these should appear.
      expect(
        expandedPath,
        anyOf(contains('/opt/homebrew/bin'), contains('/usr/local/bin')),
      );
    });
  });

  group('mergePtyEnv', () {
    test('clide defaults override the process env where they overlap', () {
      final merged = mergePtyEnv(processEnv: {
        'TERM': 'dumb',
        'CUSTOM': 'preserved',
      });
      expect(merged['TERM'], 'xterm-256color'); // clide default wins
      expect(merged['COLORTERM'], 'truecolor');
      expect(merged['CUSTOM'], 'preserved'); // process env retained
    });

    test('overrides win over both process env and clide defaults', () {
      final merged = mergePtyEnv(
        processEnv: {'TERM': 'dumb'},
        overrides: {'TERM': 'screen-256color'},
      );
      expect(merged['TERM'], 'screen-256color');
    });

    test('no overrides argument is equivalent to overrides = null', () {
      final a = mergePtyEnv(processEnv: const {'X': '1'});
      final b = mergePtyEnv(processEnv: const {'X': '1'}, overrides: null);
      expect(a, b);
    });

    test('clidePtyEnvDefaults set the expected truecolour keys', () {
      expect(clidePtyEnvDefaults['TERM'], 'xterm-256color');
      expect(clidePtyEnvDefaults['COLORTERM'], 'truecolor');
      expect(clidePtyEnvDefaults['CLICOLOR_FORCE'], '1');
    });
  });
}
