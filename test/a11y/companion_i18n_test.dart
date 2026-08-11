import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// T-530 — every string the companion asks the catalog for is actually in it.
///
/// `i18n_coverage_test` asserts the two locales are at key **parity** and that
/// catalogs ship. Neither catches the failure that matters here: a key the code
/// looks up but nobody added. That falls back to the inline English placeholder
/// and renders perfectly — in English, to a Dutch user, silently.
///
/// Scoped to this namespace because it is the one this ticket owns. The scan
/// generalises to any namespace if another wants it.
void main() {
  const namespace = 'builtin.clide-companion';
  const src = 'lib/builtin/clide_companion';

  /// `ClideSettings.i18n.string(context, 'some.key', namespace: '…'` and the
  /// `interpolated` variant.
  final lookup = RegExp(r"i18n\.(?:string|interpolated)\(\s*context,\s*'([^']+)'");

  /// Contribution manifests carry their key as a field instead (D-21/D-102).
  final manifestKey = RegExp(r"(?:titleKey|labelKey|helpKey):\s*'([^']+)'");

  Set<String> allKeys() {
    final found = <String>{};
    for (final f in Directory(src).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      // Only files that actually name this namespace — a lookup into someone
      // else's catalog is not ours to check.
      if (!text.contains(namespace)) continue;
      for (final m in lookup.allMatches(text)) {
        found.add(m.group(1)!);
      }
      for (final m in manifestKey.allMatches(text)) {
        found.add(m.group(1)!);
      }
    }
    return found;
  }

  /// Keys written out in full, which are the ones whose existence can be
  /// checked.
  Set<String> literalKeys() => allKeys().where((k) => !k.contains(r'$')).toSet();

  /// Prefixes of keys composed at runtime — `face.semantics.$key` covers the
  /// whole family.
  ///
  /// Their existence cannot be verified from source, because the suffix is a
  /// value rather than text. They are still counted as *used*, so the family
  /// does not read as dead. The face table has its own exhaustiveness guarantee
  /// (the switch over `FaceState` is compiler-checked), which is what actually
  /// covers this case.
  Set<String> usedPrefixes() => allKeys().where((k) => k.contains(r'$')).map((k) => k.substring(0, k.indexOf(r'$'))).toSet();

  bool isUsed(String key, Set<String> literals, Set<String> prefixes) => literals.contains(key) || prefixes.any(key.startsWith);

  Map<String, Object?> catalog(String locale) => (jsonDecode(File('assets/i18n/$locale/$namespace.json').readAsStringSync()) as Map).cast<String, Object?>();

  test('every key the code looks up exists in en_US', () {
    final missing = literalKeys().difference(catalog('en_us').keys.toSet());
    expect(missing, isEmpty, reason: 'looked up but never added — these render as English placeholders in every locale: $missing');
  });

  test('and in nl_NL, or a Dutch user silently reads English', () {
    final missing = literalKeys().difference(catalog('nl_nl').keys.toSet());
    expect(missing, isEmpty, reason: 'untranslated: $missing');
  });

  test('the catalog carries no keys nothing looks up', () {
    // Dead keys are not harmful, but they are a translation someone paid for
    // and a maintenance cost nobody is getting value from.
    final literals = literalKeys();
    final prefixes = usedPrefixes();
    final unused = catalog('en_us').keys.where((k) => !isUsed(k, literals, prefixes)).toList();
    expect(unused, isEmpty, reason: 'in the catalog but never asked for: $unused');
  });
}
