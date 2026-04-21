import 'dart:ui';

import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Asserts every bundled i18n catalog is well-formed and every key the
/// Tier-0 built-ins ask for actually resolves.
///
/// The second check is important: in a text-driven i18n system missing
/// keys show the placeholder, so a runtime lookup test wouldn't "fail"
/// on a typo — we have to assert the keys exist up front.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// (namespace, key) pairs referenced by Tier-0 built-ins. Extend when
  /// new keys land.
  const referenced = <String, List<String>>{
    'builtin.welcome': [
      'title',
      'subtitle',
      'open-project',
      'open-project.hint',
      'tab.title',
    ],
    'builtin.ipc-status': [
      'connected',
      'connected.hint',
      'disconnected',
      'disconnected.hint',
    ],
    'builtin.theme-picker': [
      'modal.title',
      'modal.cancel',
      'modal.cancel.hint',
      'row.select.hint',
    ],
    'builtin.default-layout': [
      'command.reset',
      'preset.classic',
    ],
  };

  group('i18n coverage (Tier 0)', () {
    for (final entry in referenced.entries) {
      final ns = entry.key;
      test('$ns catalog contains every referenced key', () async {
        final loader = AssetCatalogLoader(bundle: rootBundle);
        final catalog = await loader.load(ns, const Locale('en', 'US'));
        expect(
          catalog,
          isNotEmpty,
          reason: 'catalog for "$ns" failed to load (asset path wrong?)',
        );
        for (final key in entry.value) {
          expect(
            catalog.containsKey(key),
            isTrue,
            reason: 'namespace "$ns" catalog is missing key "$key"',
          );
        }
      });
    }
  });
}
