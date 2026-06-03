/// Theme-family helpers for the picker surfaces (T-237).
///
/// Bundled themes ship as a base + a high-contrast (`-hc`) / colour-blind
/// (`-cb`) sibling (D-69). The pickers don't list the siblings as separate
/// rows — they show base themes only and expose the variant as a "High
/// contrast" toggle. These pure helpers do the base/sibling bookkeeping so
/// the popover and the modal share one source of truth.
library;

import 'package:clide/kernel/kernel.dart' show ThemeDefinition;

bool isHcName(String name) => name.endsWith('-hc');
bool isCbName(String name) => name.endsWith('-cb');

/// The base theme name for any theme (strips a `-hc`/`-cb` suffix).
String baseThemeName(String name) => (isHcName(name) || isCbName(name)) ? name.substring(0, name.length - 3) : name;

/// Base themes only (no `-hc`/`-cb`), sorted by display name so the list is
/// stable and not "randomly" ordered.
List<ThemeDefinition> baseThemes(List<ThemeDefinition> available) =>
    available.where((t) => !isHcName(t.name) && !isCbName(t.name)).toList()..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

/// Whether [base] has a high-contrast sibling among [available].
bool hasHcSibling(List<ThemeDefinition> available, String base) => available.any((t) => t.name == '$base-hc');

/// The theme name to actually apply for a chosen [base] given the high-contrast
/// toggle: the `-hc` sibling when requested and present, else the base itself.
String resolveThemeName(List<ThemeDefinition> available, String base, {required bool highContrast}) =>
    (highContrast && hasHcSibling(available, base)) ? '$base-hc' : base;
