import 'package:alchemist/alchemist.dart';

/// Alchemist config shared across all golden tests.
///
/// Platform goldens only — keyed by OS (`goldens/linux/`, `goldens/macos/`).
/// CI goldens (Ahem font in `goldens/ci/`) are disabled because Skia's
/// geometric anti-aliasing differs between macOS and Linux even with Ahem,
/// producing sub-pixel diffs that fail cross-platform.
AlchemistConfig clideGoldenConfig() {
  return const AlchemistConfig(
    theme: null, // we're not using Material ThemeData
    platformGoldensConfig: PlatformGoldensConfig(
      enabled: true,
    ),
    ciGoldensConfig: CiGoldensConfig(
      enabled: false,
    ),
  );
}
