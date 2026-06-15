/// Tests for the consolidated PATH resolver (T-439): the login-shell probe,
/// its graceful fallbacks, and the shared `expandToolPath` merge.
library;

import 'dart:io';

import 'package:clide/src/env/shell_env.dart';
import 'package:test/test.dart';

ProcessResult _ok(String path) => ProcessResult(1, 0, '__CLIDE_PATH__${path}__CLIDE_PATH__', '');

void main() {
  setUp(debugResetLoginShellPath);
  tearDown(debugResetLoginShellPath);

  group('primeLoginShellPath', () {
    test('caches the login shell PATH so currentSearchPath returns it', () async {
      await primeLoginShellPath(shell: '/bin/zsh', run: (e, a) async => _ok('/opt/tool/bin:/usr/bin'));
      expect(currentSearchPath(), '/opt/tool/bin:/usr/bin');
    });

    test('strips profile chatter around the sentinel-framed PATH', () async {
      await primeLoginShellPath(shell: '/bin/bash', run: (e, a) async => ProcessResult(1, 0, 'MOTD: hi\n__CLIDE_PATH__/a:/b__CLIDE_PATH__', ''));
      expect(currentSearchPath(), '/a:/b');
    });

    test('falls back to the process PATH on a non-zero exit', () async {
      await primeLoginShellPath(shell: '/bin/bash', run: (e, a) async => ProcessResult(1, 1, '', 'boom'));
      expect(currentSearchPath(), Platform.environment['PATH'] ?? '');
    });

    test('falls back when the probe throws (e.g. spawn failure)', () async {
      await primeLoginShellPath(shell: '/bin/bash', run: (e, a) async => throw const ProcessException('sh', []));
      expect(currentSearchPath(), Platform.environment['PATH'] ?? '');
    });

    test('falls back when the probe times out', () async {
      await primeLoginShellPath(
        shell: '/bin/bash',
        timeout: const Duration(milliseconds: 20),
        run: (e, a) => Future.delayed(const Duration(seconds: 5), () => _ok('/never')),
      );
      expect(currentSearchPath(), Platform.environment['PATH'] ?? '');
    });

    test('falls back when SHELL is empty', () async {
      await primeLoginShellPath(shell: '', run: (e, a) async => _ok('/should/not/run'));
      expect(currentSearchPath(), Platform.environment['PATH'] ?? '');
    });

    test('is idempotent — a second call does not re-probe', () async {
      var calls = 0;
      await primeLoginShellPath(
        shell: '/bin/bash',
        run: (e, a) async {
          calls++;
          return _ok('/first');
        },
      );
      await primeLoginShellPath(
        shell: '/bin/bash',
        run: (e, a) async {
          calls++;
          return _ok('/second');
        },
      );
      expect(calls, 1);
      expect(currentSearchPath(), '/first');
    });
  });

  group('resolvedToolPath', () {
    test('unions the well-known dirs onto the resolved base', () async {
      await primeLoginShellPath(shell: '/bin/bash', run: (e, a) async => _ok('/usr/bin'));
      final got = resolvedToolPath();
      // The resolved base is preserved; on macOS/Linux the user/local dirs are
      // unioned in. (Windows passes through, so only assert the base is kept.)
      expect(got.split(':'), contains('/usr/bin'));
      if (Platform.isLinux || Platform.isMacOS) {
        expect(got.split(':'), contains('/usr/local/bin'));
      }
    });
  });

  group('expandToolPath', () {
    test('prepends missing user/local dirs (Linux), de-duplicated, base last', () {
      final out = expandToolPath('/usr/bin', isMac: false, isLinux: true, home: '/home/u').split(':');
      expect(out, contains('/home/u/.local/bin'));
      expect(out, contains('/usr/local/bin'));
      expect(out.last, '/usr/bin');
    });

    test('does not duplicate dirs already present', () {
      final out = expandToolPath('/usr/local/bin:/usr/bin', isMac: false, isLinux: true, home: '');
      expect('/usr/local/bin'.allMatches(out).length, 1);
    });

    test('passes the base through unchanged off macOS/Linux', () {
      expect(expandToolPath('/a:/b', isMac: false, isLinux: false, home: '/home/u'), '/a:/b');
    });
  });
}
