import 'dart:io' show Platform;

import 'package:alchemist/alchemist.dart';

/// Alchemist config shared across all golden tests.
///
/// Platform goldens only — keyed by OS (`goldens/linux/`, `goldens/macos/`).
/// CI goldens (Ahem font in `goldens/ci/`) are disabled because Skia's
/// geometric anti-aliasing differs between macOS and Linux even with Ahem,
/// producing sub-pixel diffs that fail cross-platform.
///
/// Platform goldens are font/render-dependent ACROSS machines too: a golden
/// generated on one Linux box (the dev's Fedora) does not match a GitHub
/// `ubuntu-latest` runner even though both are "linux" — different freetype /
/// font packages render sub-pixel-differently. So on CI (detected via the `CI`
/// env var) the goldens still RUN — keeping the widget paint code covered for
/// the coverage gate — but in update mode: they regenerate instead of comparing,
/// so font differences can't fail them and the throwaway runner's regenerated
/// PNGs are discarded. Pixel validation happens locally before merge (CI unset →
/// normal compare).
AlchemistConfig clideGoldenConfig() {
  final isCi = Platform.environment.containsKey('CI');
  return AlchemistConfig(
    theme: null, // we're not using Material ThemeData
    forceUpdateGoldenFiles: isCi,
    platformGoldensConfig: const PlatformGoldensConfig(enabled: true),
    ciGoldensConfig: const CiGoldensConfig(enabled: false),
  );
}
