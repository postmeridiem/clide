/// Guard the serial-suite list in `ci/test.sh`.
///
/// The serial pass names its files explicitly rather than selecting purely by
/// tag, because `flutter test --tags serial` with no paths compiles and loads
/// **every** suite to discover which ones carry the tag — and at
/// `--concurrency=1` that discovery is serial. Measured: 156s to run 50 tests,
/// against 6s when the three files are named. It was 75% of the suite's wall
/// clock for 1% of its tests.
///
/// The cost of naming them is that a newly-tagged suite silently stops running,
/// which is the worst failure a test file can have: it reports green by not
/// existing. So this reads the live `SERIAL_TESTS` array out of `ci/test.sh` and
/// compares it against what the tree actually tags.
///
/// Same shape as `pre_push_hook_test.dart` — the shell script stays the single
/// source of truth and the test reads it, rather than the two keeping separate
/// copies of the same list.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final script = File('ci/test.sh');

  test('ci/test.sh exists', () {
    expect(script.existsSync(), isTrue, reason: 'expected ci/test.sh at the repo root');
  });

  final src = script.readAsStringSync();
  final block = RegExp(r'SERIAL_TESTS=\(([^)]*)\)').firstMatch(src);

  test('it declares a SERIAL_TESTS list', () {
    expect(block, isNotNull, reason: 'could not find SERIAL_TESTS=( … ) in ci/test.sh');
  });

  final named = block!.group(1)!.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty && !l.startsWith('#')).toSet();

  /// Every suite that actually carries the tag, however it is spelled — the
  /// file-level `@Tags(['serial'])` annotation or a `tags: 'serial'` argument on
  /// a group or test.
  Set<String> tagged() {
    final tag = RegExp(r"""@Tags\(\s*\[\s*'serial'|tags:\s*(?:'serial'|\[[^\]]*'serial')""");
    return Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))
        // This file necessarily contains the pattern it searches for, so a
        // textual scan finds itself. It is tagged `vm`, not `serial`.
        .where((f) => !f.path.endsWith('serial_tags_test.dart'))
        .where((f) => tag.hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toSet();
  }

  test('every serial-tagged suite is named in ci/test.sh', () {
    // A tagged suite the script does not name is excluded from the parallel
    // pool AND never picked up by the serial pass — it stops running entirely,
    // and the suite still reports green.
    final missing = tagged().difference(named);
    expect(missing, isEmpty, reason: 'tagged serial but not in SERIAL_TESTS, so they run nowhere: $missing');
  });

  test('and nothing is named that is not tagged', () {
    // A stale entry is harmless to correctness but means the file runs in both
    // passes — once in the parallel pool, once here — which is how a
    // concurrency-vulnerable test starts flaking again.
    final stale = named.difference(tagged());
    expect(stale, isEmpty, reason: 'named in SERIAL_TESTS but no longer tagged serial: $stale');
  });
}
