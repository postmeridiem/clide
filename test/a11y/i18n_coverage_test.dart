import 'dart:io';
import 'dart:ui';

import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// i18n coverage gate.
///
/// The subject list is derived from the shipped catalogs on disk
/// (`assets/i18n/en_us/*.json`), NOT a hand-maintained list — so a newly
/// added catalog is validated automatically and cannot ship unchecked
/// (T-371; the old gate hand-enumerated 4 of the namespaces and silently
/// covered less as the app grew).
///
/// Per catalog we assert: the en_US catalog loads and is non-empty, and the
/// nl_NL pack is at exact key parity (no missing or extra keys) — so a locale
/// switch never falls back to English for a shipped string, and a stray
/// translation key can't rot unnoticed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const enDir = 'assets/i18n/en_us';
  final namespaces = Directory(
    enDir,
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.json')).map((f) => f.uri.pathSegments.last.replaceAll('.json', '')).toList()..sort();

  group('i18n coverage — every shipped catalog', () {
    test('the asset dir actually ships catalogs', () {
      expect(namespaces, isNotEmpty, reason: 'no catalogs found under $enDir');
    });

    for (final ns in namespaces) {
      test('$ns: en_US loads non-empty, nl_NL at key parity', () async {
        final loader = AssetCatalogLoader(bundle: rootBundle);
        final en = await loader.load(ns, const Locale('en', 'US'));
        expect(en, isNotEmpty, reason: 'en_US catalog for "$ns" failed to load (asset path wrong?)');
        final nl = await loader.load(ns, const Locale('nl', 'NL'));
        expect(nl, isNotEmpty, reason: 'nl_NL catalog for "$ns" missing or empty');

        final enKeys = en.keys.toSet();
        final nlKeys = nl.keys.toSet();
        expect(nlKeys.difference(enKeys), isEmpty, reason: 'nl_NL "$ns" has keys absent from en_US: ${nlKeys.difference(enKeys)}');
        expect(enKeys.difference(nlKeys), isEmpty, reason: 'nl_NL "$ns" is missing keys present in en_US: ${enKeys.difference(nlKeys)}');
      });
    }
  });

  // The Tier-0 preload list (loaded at boot, before its owning extension
  // activates) must name only catalogs that actually ship — else boot preloads
  // a missing namespace. The reverse isn't required: most catalogs load lazily
  // on extension activation, not at boot.
  group('i18n coverage — Tier-0 preload set is honest', () {
    test('every kTier0Namespaces entry has a shipped en_US catalog', () {
      final shipped = namespaces.toSet();
      for (final ns in kTier0Namespaces) {
        expect(shipped.contains(ns), isTrue, reason: 'kTier0Namespaces names "$ns" but no $enDir/$ns.json ships');
      }
    });
  });
}
