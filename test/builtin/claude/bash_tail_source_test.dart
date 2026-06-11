/// Unit tests for the Bash live-tail source parser (T-325).
library;

import 'dart:io';

import 'package:clide/builtin/claude/src/bash_tail_source.dart';
import 'package:test/test.dart';

void main() {
  // resolveUnderRoot is pure string normalisation — the dir need not exist.
  final root = Directory('/repo');
  String? detect(String cmd) => detectBashTailSource(cmd, workspaceRoot: root);

  group('detectBashTailSource — followable file sources (T-325)', () {
    test('tail -f a relative file', () {
      expect(detect('tail -f app.log'), '/repo/app.log');
    });

    test('tail -f a nested file', () {
      expect(detect('tail -f logs/build.log'), '/repo/logs/build.log');
    });

    test('tail with -n N before the file', () {
      expect(detect('tail -n 200 -f logs/build.log'), '/repo/logs/build.log');
    });

    test('tail -F (retry-follow)', () {
      expect(detect('tail -F server.log'), '/repo/server.log');
    });

    test('cat a file', () {
      expect(detect('cat notes.txt'), '/repo/notes.txt');
    });

    test('less a file', () {
      expect(detect('less README.md'), '/repo/README.md');
    });

    test('an absolute path INSIDE the workspace is followed', () {
      expect(detect('tail -f /repo/sub/x.log'), '/repo/sub/x.log');
    });

    test('a quoted path with a space', () {
      expect(detect('cat "my file.log"'), '/repo/my file.log');
    });

    test('a redirect after the file is ignored', () {
      expect(detect('tail -f app.log 2>/dev/null'), '/repo/app.log');
    });

    test('a downstream pipe stage is ignored; the tail still has its file', () {
      expect(detect('tail -f logs/app.log | grep ERROR'), '/repo/logs/app.log');
    });

    test('two segments naming the SAME file resolve to one source', () {
      expect(detect('cat a.txt && tail -f a.txt'), '/repo/a.txt');
    });
  });

  group('detectBashTailSource — no followable source (T-325)', () {
    test('a pipe INTO tail (reads stdin, no file)', () {
      expect(detect('git push origin main | tail -25'), isNull);
    });

    test('tail -f reading a pipe (no file arg)', () {
      expect(detect('cmd | tail -f'), isNull);
    });

    test('a non-follow command', () {
      expect(detect('echo hi'), isNull);
    });

    test('an absolute path OUTSIDE the workspace', () {
      expect(detect('tail -f /etc/passwd'), isNull);
    });

    test('a traversal escaping the workspace', () {
      expect(detect('tail -f ../secrets.txt'), isNull);
    });

    test('two distinct files are ambiguous', () {
      expect(detect('tail -f a.log b.log'), isNull);
    });

    test('two segments naming DIFFERENT files are ambiguous', () {
      expect(detect('cat a.txt && tail -f b.txt'), isNull);
    });

    test('empty command', () {
      expect(detect(''), isNull);
    });
  });

  group('bashHasTailIntent — when to surface the segment (T-325)', () {
    test('a tail command has tail intent (even into a pipe → "nothing to follow")', () {
      expect(bashHasTailIntent('tail -f app.log'), isTrue);
      expect(bashHasTailIntent('tail -100 app.log'), isTrue);
      expect(bashHasTailIntent('git push | tail -25'), isTrue);
    });

    test('a bare follow flag counts', () {
      expect(bashHasTailIntent('some-cmd --follow build.log'), isTrue);
    });

    test('ordinary commands have no tail intent (no segment)', () {
      expect(bashHasTailIntent('ls -la'), isFalse);
      expect(bashHasTailIntent('git status'), isFalse);
      expect(bashHasTailIntent('cat README.md'), isFalse); // cat is detectable but not a v1 trigger
      expect(bashHasTailIntent('grep -rn foo lib/'), isFalse);
    });
  });
}
