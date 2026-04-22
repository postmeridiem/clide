import 'package:alchemist/alchemist.dart';

/// Alchemist config shared across all golden tests.
///
/// * CI mode uses the Ahem font (shipped with Flutter's test harness) so
///   goldens render identically on every Linux runner and developer
///   machine. Any drift between platforms points to a real theme-token
///   regression, not a font-rendering fluke.
/// * Local mode keeps developer-machine fonts so you can eyeball
///   renders naturally; the `--update-goldens` workflow still produces
///   CI-valid goldens because CI runs the config below.
AlchemistConfig clideGoldenConfig({bool forceCiMode = false}) {
  return AlchemistConfig(
    theme: null, // we're not using Material ThemeData
    platformGoldensConfig: PlatformGoldensConfig(
      enabled: !forceCiMode,
    ),
    ciGoldensConfig: const CiGoldensConfig(
      enabled: true,
    ),
  );
}
