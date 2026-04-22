/// Typography constants shared across widgets.
///
/// Terminal panes, diff views, and any other monospace surface should
/// import from here rather than hardcoding a family. The fallback chain
/// exists for web builds + platforms where the bundled `JetBrainsMono`
/// asset isn't picked up (rare, but possible during `flutter test` if
/// assets aren't declared in the harness).
library;

/// The bundled monospace family. Always resolved first.
const String clideMonoFamily = 'JetBrainsMono';

/// System fallback chain. Ordered by platform prevalence + quality of
/// programming-ligature / box-drawing coverage.
const List<String> clideMonoFamilyFallback = [
  // macOS
  'SF Mono',
  'Menlo',
  'Monaco',
  // Linux
  'JetBrains Mono',  // if the user has it system-installed under the
                     // canonical PostScript name
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
