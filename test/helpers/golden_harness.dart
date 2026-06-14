import 'dart:io' show Platform;

import 'package:alchemist/alchemist.dart';

/// Alchemist config shared across all golden tests.
///
/// Platform goldens only — keyed by OS (`goldens/linux/`, `goldens/macos/`).
/// CI goldens (Ahem font in `goldens/ci/`) are disabled because Skia's
/// geometric anti-aliasing differs between macOS and Linux even with Ahem,
/// producing sub-pixel diffs that fail cross-platform.
///
/// Platform goldens are also font/render-dependent ACROSS machines: a golden
/// generated on one Linux box (the dev's Fedora) does not match a GitHub
/// `ubuntu-latest` runner even though both are "linux" — different freetype /
/// font packages render sub-pixel-differently. So platform goldens run only
/// locally (dev-validated before merge) and are skipped on CI (detected via the
/// `CI` env var GitHub Actions sets). Goldens are a local check, not a CI gate.
AlchemistConfig clideGoldenConfig() {
  final isCi = Platform.environment.containsKey('CI');
  return AlchemistConfig(
    theme: null, // we're not using Material ThemeData
    platformGoldensConfig: PlatformGoldensConfig(enabled: !isCi),
    ciGoldensConfig: const CiGoldensConfig(enabled: false),
  );
}
