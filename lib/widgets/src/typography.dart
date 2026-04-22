/// Typography constants shared across widgets.
///
/// Two bundled families:
///
/// - [clideUiFamily] — Josefin Sans, the application-wide UI face.
///   Shipped as a variable font (weights 100-700) + italic companion;
///   default weight is [clideUiDefaultWeight] (Light / `w300`).
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

/// The bundled application UI family. Always resolved first.
const String clideUiFamily = 'JosefinSans';

/// Default weight for UI text. Josefin Sans reads well at Light; the
/// rest of the design adjusts contrast and size to stay legible.
const FontWeight clideUiDefaultWeight = FontWeight.w300;

/// System fallback chain for the UI face. Sans-serif humanist faces
/// that sit close to Josefin's proportions, ordered by platform.
const List<String> clideUiFamilyFallback = [
  // User system install of Josefin, if any.
  'Josefin Sans',
  // Platform humanist sans defaults.
  'Inter',
  'Helvetica Neue',
  'Helvetica',
  'Arial',
  'sans-serif',
];

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
