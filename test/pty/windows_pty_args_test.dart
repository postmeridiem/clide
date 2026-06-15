/// Cross-platform unit tests for the pure Windows-backend helpers in
/// `windows_pty.dart`: MSVCRT command-line quoting, PATH/PATHEXT executable
/// resolution, and CreateProcess environment-block composition.
///
/// These touch no Win32 API, so they run on every platform — the FFI
/// bindings in windows_pty.dart are lazily initialized top-level finals and
/// are never accessed here. This is the off-Windows coverage for logic the
/// `windows_pty_test.dart` smoke suite can only exercise on Windows.
library;

import 'package:clide/src/pty/windows_pty.dart';
import 'package:test/test.dart';

void main() {
  group('quoteArg (MSVCRT command-line rules)', () {
    test('leaves an argument with no special chars untouched', () {
      expect(WindowsPty.quoteArg('simple'), 'simple');
      expect(WindowsPty.quoteArg('C:\\path\\to\\tool.exe'), 'C:\\path\\to\\tool.exe');
    });

    test('quotes an empty argument so it survives as a distinct token', () {
      expect(WindowsPty.quoteArg(''), '""');
    });

    test('quotes arguments containing spaces or tabs', () {
      expect(WindowsPty.quoteArg('has space'), '"has space"');
      expect(WindowsPty.quoteArg('has\ttab'), '"has\ttab"');
    });

    test('escapes an embedded double quote with a backslash', () {
      // a"b  ->  "a\"b"
      expect(WindowsPty.quoteArg('a"b'), '"a\\"b"');
    });

    test('doubles a run of backslashes that precedes the closing quote', () {
      // a b\  ->  "a b\\"   (trailing backslash doubled before the ")
      expect(WindowsPty.quoteArg('a b\\'), '"a b\\\\"');
    });

    test('backslashes before an embedded quote are doubled, plus one to escape it', () {
      // a\"b  ->  "a\\\"b"
      expect(WindowsPty.quoteArg('a\\"b'), '"a\\\\\\"b"');
    });
  });

  group('composeEnvironmentBlock', () {
    final z = String.fromCharCode(0);

    test('sorts entries case-insensitively, NUL-terminates each, ends double-NUL', () {
      final block = WindowsPty.composeEnvironmentBlock({'bee': '2', 'Apple': '1', 'cat': '3'});
      expect(block, 'Apple=1${z}bee=2${z}cat=3$z$z');
    });

    test('an empty environment is a single NUL (toNativeUtf16 adds the second)', () {
      expect(WindowsPty.composeEnvironmentBlock({}), z);
    });

    test('preserves = and values verbatim', () {
      expect(WindowsPty.composeEnvironmentBlock({'PATH': r'C:\a;C:\b'}), 'PATH=C:\\a;C:\\b$z$z');
    });
  });

  group('resolveExecutable (PATH + PATHEXT, injected existence probe)', () {
    test('returns a path with a known extension as-is when it exists', () {
      final r = WindowsPty.resolveExecutable('C:\\tools\\foo.exe', {'PATHEXT': '.EXE'}, exists: (p) => p == 'C:\\tools\\foo.exe');
      expect(r, 'C:\\tools\\foo.exe');
    });

    test('appends a PATHEXT extension to a bare name found on PATH', () {
      final r = WindowsPty.resolveExecutable('foo', {'PATH': 'C:\\bin;C:\\other', 'PATHEXT': '.COM;.EXE'}, exists: (p) => p == 'C:\\bin\\foo.EXE');
      expect(r, 'C:\\bin\\foo.EXE');
    });

    test('tries PATH dirs in order and stops at the first hit', () {
      final probed = <String>[];
      final r = WindowsPty.resolveExecutable(
        'bar',
        {'PATH': 'C:\\a;C:\\b', 'PATHEXT': '.EXE'},
        exists: (p) {
          probed.add(p);
          return p == 'C:\\b\\bar.EXE';
        },
      );
      expect(r, 'C:\\b\\bar.EXE');
      expect(probed, contains('C:\\a\\bar')); // probed the first dir before the hit in the second
    });

    test('returns the bare name unchanged when nothing resolves', () {
      final r = WindowsPty.resolveExecutable('nope', {'PATH': 'C:\\bin', 'PATHEXT': '.EXE'}, exists: (_) => false);
      expect(r, 'nope');
    });
  });
}
