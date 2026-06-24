import 'dart:io';

import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// WCAG-AA contrast gate. Every bundled theme's token pairs (listed in
/// [canonicalPairs]) must clear 4.5:1 for normal text / 3:1 for large
/// text. Failing pairs are printed with their computed ratio so a
/// theme-token regression shows exactly which pair broke.
///
/// Themes whose name ends in `-hc` (high-contrast) or `-cb`
/// (colour-blind) additionally have to clear the stricter
/// [extendedPairs] set — D-69.
///
/// The subject list is [kBundledThemePaths] — the SAME list main.dart loads
/// and the testmode harness validates (T-371). A meta-test asserts every
/// `.yaml` on disk is in that list, so a new theme cannot ship unvalidated.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('contrast — all bundled themes meet WCAG AA', () {
    for (final path in kBundledThemePaths) {
      test('theme: $path', () async {
        final def = await const ThemeLoader().fromAsset(rootBundle, path);
        const resolver = ThemeResolver();
        final tokens = resolver.resolve(
          palette: def.palette,
          semanticOverride: def.semanticOverride,
          surfaceOverride: def.surfaceOverride,
          extensionOverride: def.extensionOverride,
        );
        final failures = failingPairs(tokens);
        if (failures.isNotEmpty) {
          fail(
            'Contrast failures in ${def.name}:\n'
            '${failures.map((f) => '  - $f').join('\n')}',
          );
        }
        final isStrict = def.name.endsWith('-hc') || def.name.endsWith('-cb');
        if (isStrict) {
          final extended = failingExtendedPairs(tokens);
          if (extended.isNotEmpty) {
            fail(
              'Extended contrast failures in ${def.name} (strict gate):\n'
              '${extended.map((f) => '  - $f').join('\n')}',
            );
          }
        }
      });
    }
  });

  // Drift guard (T-371): a theme YAML on disk that isn't in kBundledThemePaths
  // would never be loaded, shipped, or contrast-checked. Fail loudly so a new
  // theme has to be added to the canonical list (which auto-validates it above)
  // rather than sit on disk unvalidated.
  test('every theme YAML on disk is in kBundledThemePaths', () {
    final onDisk = Directory(
      kThemesDir,
    ).listSync().whereType<File>().map((f) => f.path).where((p) => p.endsWith('.yaml')).map((p) => p.replaceAll(r'\', '/')).toSet();
    final bundled = kBundledThemePaths.toSet();
    final unbundled = onDisk.difference(bundled);
    expect(unbundled, isEmpty, reason: 'theme YAML(s) on disk but not in kBundledThemePaths (so unvalidated/unshipped): $unbundled');
    final missing = bundled.difference(onDisk);
    expect(missing, isEmpty, reason: 'kBundledThemePaths references missing file(s): $missing');
  });
}
