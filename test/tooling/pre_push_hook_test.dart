/// T-393: guard the pre-push fast-path classifier.
///
/// The hook runs the full ~2min gate only when the pushed diff touches a
/// "trigger" path; everything else rides along on the next triggering push.
/// The regex once matched ONLY `lib/` + `pubspec.*`, so a push that ONLY
/// changed a test, a ci/ gate script, or the hook itself skipped the entire
/// suite. This test reads the live `trigger_re` from `.githooks/pre-push` (the
/// single source of truth) and asserts the load-bearing dirs force the gate, so
/// the regex can't be silently narrowed back.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final hook = File('.githooks/pre-push');

  test('the pre-push hook exists', () {
    expect(hook.existsSync(), isTrue, reason: 'expected .githooks/pre-push at the repo root');
  });

  // Extract `trigger_re='...'` from the hook and apply it the way grep -E does.
  final src = hook.readAsStringSync();
  final m = RegExp(r"""trigger_re='([^']*)'""").firstMatch(src);

  test('the hook defines a trigger_re pattern', () {
    expect(m, isNotNull, reason: 'could not find trigger_re=\'...\' in .githooks/pre-push');
  });

  final pattern = RegExp(m!.group(1)!);
  bool forcesGate(String path) => pattern.hasMatch(path);

  group('forces the full gate', () {
    const triggers = [
      'lib/main.dart',
      'lib/src/editor/registry.dart',
      'test/foo_test.dart',
      'test/a11y/contrast_test.dart',
      'ci/test.sh',
      'ci/changelog_gate.sh',
      '.githooks/pre-push',
      'pubspec.yaml',
      'pubspec.lock',
    ];
    for (final p in triggers) {
      test(p, () => expect(forcesGate(p), isTrue, reason: '$p must run the full gate'));
    }
  });

  group('rides along (no full gate)', () {
    // Docs, assets, governance, and top-level notes can ride along with the
    // next lib-touching push — they cannot break the test suite or the gate.
    const ridesAlong = ['docs/initial-plan.md', 'assets/logo/logo.svg', 'governance/decisions/process.md', 'README.md', 'CHANGELOG.md'];
    for (final p in ridesAlong) {
      test(p, () => expect(forcesGate(p), isFalse, reason: '$p should not force the full gate'));
    }
  });
}
