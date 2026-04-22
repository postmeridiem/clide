import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// WCAG-AA contrast gate. Every bundled theme's token pairs (listed in
/// [canonicalPairs]) must clear 4.5:1 for normal text / 3:1 for large
/// text. Failing pairs are printed with their computed ratio so a
/// theme-token regression shows exactly which pair broke.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('contrast — all bundled themes meet WCAG AA', () {
    const bundledPaths = [
      'lib/kernel/src/theme/themes/clide.yaml',
      'lib/kernel/src/theme/themes/midnight.yaml',
      'lib/kernel/src/theme/themes/paper.yaml',
      'lib/kernel/src/theme/themes/terminal.yaml',
    ];

    for (final path in bundledPaths) {
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
      });
    }
  });
}
