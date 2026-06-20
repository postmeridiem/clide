/// Typography constants shared across widgets.
///
/// Two bundled families:
///
/// - [clideUiFamily] — Inter, the application-wide UI face (T-460; was
///   Josefin Sans). Shipped as a variable font + italic companion. Users can
///   switch it from Settings → Appearance via the [kUiFontSettingKey] override.
/// - [clideMonoFamily] — JetBrains Mono, for terminal panes, diff
///   views, code editors, and any other monospace surface.
///
/// Fallback chains exist for web builds + harnesses where the bundled
/// asset isn't picked up (rare, but possible during `flutter test` if
/// asset fonts aren't declared in the harness).
library;

import 'package:flutter/widgets.dart' show FontWeight;

// ---------------------------------------------------------------------------
// UI face — Josefin Sans
// ---------------------------------------------------------------------------

/// The bundled default application UI family, resolved first. Inter stays
/// bundled and selectable (Settings → Appearance); the settings override
/// ([kUiFontSettingKey]) takes precedence at the app root when set.
const String clideUiFamily = 'JosefinSans';

/// Default weight for UI text — Josefin Sans reads best at Light.
const FontWeight clideUiDefaultWeight = FontWeight.w300;

/// System fallback chain for the UI face — the other bundled UI option plus
/// platform humanist sans defaults.
const List<String> clideUiFamilyFallback = [
  // The other bundled UI family (selectable in Appearance).
  'Inter',
  // User system install / platform humanist sans defaults.
  'Helvetica Neue',
  'Helvetica',
  'Arial',
  'sans-serif',
];

/// Settings keys for the user-selectable UI / monospace font families
/// (Settings → Appearance, T-460). Unset → the bundled defaults above.
const String kUiFontSettingKey = 'app.ui.font';
const String kMonoFontSettingKey = 'app.mono.font';

/// Settings key for the UI language (Settings → Appearance, T-462). Value is a
/// `lang_country` string (e.g. `en_US`, `nl_NL`); unset → the default locale.
const String kLocaleSettingKey = 'app.locale';

// ---------------------------------------------------------------------------
// Monospace face — JetBrains Mono
// ---------------------------------------------------------------------------

/// The bundled monospace family. Always resolved first.
const String clideMonoFamily = 'JetBrainsMono';

// ---------------------------------------------------------------------------
// Type scale — semantic sizes. Widgets inherit from the ambient
// DefaultTextStyle (set at the app root). Only override when the
// semantic role genuinely differs from body text. Prefer these
// constants over bare numbers so the scale stays coherent.
// ---------------------------------------------------------------------------

const double clideFontBody = 15;
const double clideFontCaption = 14;
const double clideFontMono = 14;
const double clideFontMeta = 13;
const double clideFontSmall = 12;
const double clideFontBadge = 11;
// Larger semantic sizes that aren't body text. clideFontDialogTitle is
// the modal/dialog heading; clideFontWelcomeBanner is the oversized
// "clide" mark on the welcome screen — one-off but worth naming.
const double clideFontDialogTitle = 16;
const double clideFontWelcomeBanner = 52;
const double clideLineHeight = 1.25;

/// System fallback chain. Ordered by platform prevalence + quality of
/// programming-ligature / box-drawing coverage.
const List<String> clideMonoFamilyFallback = [
  // macOS
  'SF Mono',
  'Menlo',
  'Monaco',
  // Linux — user system install under the canonical PostScript name
  'JetBrains Mono',
  'Fira Code',
  'Hack',
  'DejaVu Sans Mono',
  'Liberation Mono',
  // Windows
  'Cascadia Code',
  'Consolas',
  // Last resort
  'monospace',
];
