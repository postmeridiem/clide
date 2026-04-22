/// `PtySession` smoke tests.
///
/// Exercises the real `ptyc` binary end-to-end: socketpair → spawn →
/// SCM_RIGHTS fd receive → child output through the reader isolate.
/// Linux + macOS only; skipped elsewhere.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:test/test.dart';

void main() {
  if (!Platform.isLinux && !Platform.isMacOS) {
    return; // POSIX-only wrapper for now.
  }

  final ptycPath = _resolvePtyc();

  group('PtySession', () {
    test('spawns /bin/echo and reads its output', () async {
      final s = await PtySession.spawn(
        argv: const ['/bin/echo', 'hello-pty'],
        ptycPath: ptycPath,
      );
      addTearDown(s.close);

      final buf = StringBuffer();
      final sub = s.output.listen((bytes) => buf.write(utf8.decode(bytes)));
      try {
        // echo exits quickly; give the reader up to 2s to see its
        // output before we assert.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        for (var i = 0; i < 20 && !buf.toString().contains('hello-pty'); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      } finally {
        await sub.cancel();
      }

      expect(buf.toString(), contains('hello-pty'));
      expect(s.pid, greaterThan(0));
    });

    test('write round-trips through /bin/cat', () async {
      final s = await PtySession.spawn(
        argv: const ['/bin/cat'],
        ptycPath: ptycPath,
      );
      addTearDown(s.close);

      final got = Completer<String>();
      final buf = StringBuffer();
      s.output.listen((bytes) {
        buf.write(utf8.decode(bytes));
        if (buf.toString().contains('echo-me')) {
          if (!got.isCompleted) got.complete(buf.toString());
        }
      });

      // Give the PTY a moment to be ready.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      s.write(utf8.encode('echo-me\n'));

      final out = await got.future.timeout(const Duration(seconds: 3));
      expect(out, contains('echo-me'));
    });

    test('COLORTERM truecolor propagates to the child', () async {
      // `/usr/bin/env` prints the child's environment. We should see
      // COLORTERM=truecolor because clidePtyEnvDefaults sets it.
      final s = await PtySession.spawn(
        argv: const ['/usr/bin/env'],
        ptycPath: ptycPath,
      );
      addTearDown(s.close);

      final buf = StringBuffer();
      final sub = s.output.listen((bytes) => buf.write(utf8.decode(bytes)));
      try {
        for (var i = 0; i < 20; i++) {
          if (buf.toString().contains('COLORTERM=truecolor')) break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      } finally {
        await sub.cancel();
      }

      expect(buf.toString(), contains('COLORTERM=truecolor'));
      expect(buf.toString(), contains('TERM=xterm-256color'));
    });

    test('close is idempotent and stops the stream', () async {
      final s = await PtySession.spawn(
        argv: const ['/bin/cat'],
        ptycPath: ptycPath,
      );
      expect(s.isClosed, isFalse);
      await s.close();
      expect(s.isClosed, isTrue);
      await s.close(); // second call should not throw
    });
  });
}

/// Locate the `ptyc` binary relative to the repo root, falling back to
/// PATH. Lets tests run in fresh clones before anyone's touched PATH.
String _resolvePtyc() {
  final devPath = File('ptyc/bin/ptyc');
  if (devPath.existsSync()) return devPath.absolute.path;
  return 'ptyc';
}
