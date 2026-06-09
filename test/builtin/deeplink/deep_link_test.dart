/// Tests for the clide:// deep-link parser + paranoid allowlist (T-56, D-90).
/// The allowlist is the security boundary, so it gets the bulk of the coverage.
library;

import 'package:clide/builtin/deeplink/src/deep_link.dart';
import 'package:test/test.dart';

void main() {
  group('parseDeepLink — open', () {
    test('parses path + optional line', () {
      final a = parseDeepLink('clide://open?path=/repo/x.dart')!;
      expect(a.name, 'open');
      expect(a.path, '/repo/x.dart');
      expect(a.line, isNull);

      final b = parseDeepLink('clide://open?path=/repo/x.dart&line=42')!;
      expect(b.line, 42);
    });

    test('decodes a percent-encoded path', () {
      expect(parseDeepLink('clide://open?path=/a%20b/c.dart')!.path, '/a b/c.dart');
    });

    test('describe reads naturally for the prompt', () {
      expect(parseDeepLink('clide://open?path=/x&line=9')!.describe, contains('/x'));
      expect(parseDeepLink('clide://open?path=/x&line=9')!.describe, contains('9'));
    });

    test('missing/empty path is rejected', () {
      expect(parseDeepLink('clide://open'), isNull);
      expect(parseDeepLink('clide://open?path='), isNull);
    });

    test('a non-positive or non-numeric line is rejected (no guessing)', () {
      expect(parseDeepLink('clide://open?path=/x&line=0'), isNull);
      expect(parseDeepLink('clide://open?path=/x&line=-3'), isNull);
      expect(parseDeepLink('clide://open?path=/x&line=abc'), isNull);
    });
  });

  group('paranoid allowlist (default-deny) — the security boundary', () {
    test('the allowlist is exactly the safe navigation set', () {
      expect(kDeepLinkSafeActions, {'open'});
    });

    test('a non-allowlisted action is rejected even if well-formed', () {
      // These are the kind of things a malicious page might try.
      expect(parseDeepLink('clide://run?cmd=rm'), isNull);
      expect(parseDeepLink('clide://git?verb=push'), isNull);
      expect(parseDeepLink('clide://write?path=/x&content=evil'), isNull);
      expect(parseDeepLink('clide://exec?path=/x'), isNull);
    });

    test('a non-clide scheme or garbage is rejected', () {
      expect(parseDeepLink('https://evil.com/open?path=/x'), isNull);
      expect(parseDeepLink('file:///etc/passwd'), isNull);
      expect(parseDeepLink('not a url at all'), isNull);
      expect(parseDeepLink(''), isNull);
    });
  });
}
