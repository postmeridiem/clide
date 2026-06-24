/// Canonical list of the bundled theme asset paths — the single source of
/// truth for which themes ship (T-371).
///
/// Three consumers used to hand-maintain their own copy and drifted apart
/// (main.dart loaded 10, the testmode harness loaded 8 — catppuccin was
/// silently unvalidated, and the WCAG contrast gate had a third copy):
///
/// - `lib/main.dart` `_loadBundledThemes()` — what the running app loads.
/// - `lib/test_app.dart` — the testmode platform-integration harness.
/// - `test/a11y/contrast_test.dart` — the WCAG-AA contrast gate.
///
/// They now all iterate this list, so adding a theme here loads it, validates
/// it, and ships it everywhere at once. The contrast gate additionally asserts
/// every `.yaml` under [kThemesDir] is in this list, so a new theme cannot sit
/// on disk (or ship) unvalidated.
library;

/// Directory holding the theme YAML sources, relative to the repo root.
const String kThemesDir = 'lib/kernel/src/theme/themes';

/// Theme YAML asset paths bundled into the app, in display order: the base
/// themes, then their `-hc` high-contrast siblings, then third-party / ported
/// palettes paired with their own `-hc` siblings. Every base theme has a
/// structurally identical `-hc` sibling that clears the strict contrast gate.
const List<String> kBundledThemePaths = [
  '$kThemesDir/clide.yaml',
  '$kThemesDir/midnight.yaml',
  '$kThemesDir/paper.yaml',
  '$kThemesDir/terminal.yaml',
  '$kThemesDir/clide-hc.yaml',
  '$kThemesDir/midnight-hc.yaml',
  '$kThemesDir/paper-hc.yaml',
  '$kThemesDir/terminal-hc.yaml',
  '$kThemesDir/catppuccin-mocha.yaml',
  '$kThemesDir/catppuccin-mocha-hc.yaml',
  '$kThemesDir/summer-night.yaml',
  '$kThemesDir/summer-night-hc.yaml',
];
