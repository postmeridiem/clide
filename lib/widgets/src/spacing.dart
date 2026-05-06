/// Spacing constants shared across widgets.
///
/// Three categories — every widget that picks a literal pixel value
/// for layout should pull it from one of these instead:
///
/// 1. **Insets** — padding inside containers around content
///    (text breathing room, icon micro-margin).
/// 2. **Gaps** — distance between siblings in a Row or Column.
/// 3. **Sizes** — control dimensions (icon glyph size, hit-target
///    outer size, button/row/tab height).
///
/// Values are paired with the geometry rules under
/// `.claude/skills/ui-design/references/geometry.md` (uniform inner
/// spacing, no double-edge padding, two-column control pattern).
/// Adjust here only — never inline literals.
library;

// ---------------------------------------------------------------------------
// Insets — padding inside containers
// ---------------------------------------------------------------------------

/// Hairline. Used for divider thickness and the terminal cell padding
/// where 1px would clip glyphs.
const double clideInsetHairline = 2;

/// Tight inset for compact controls (sidebar item gutter).
const double clideInsetTight = 4;

/// Uniform breathing room around an icon inside a control. Pair with
/// a 16x16 hit target inside a 28-tall control: top/bottom auto-fall
/// to (28 − 16) / 2 = 6, so a matching right padding of 6 yields a
/// uniform border on the constrained sides.
const double clideInsetIcon = 6;

/// Standard gap between adjacent inline elements in a row (icon → text,
/// text → action). Used as the in-row SizedBox between a title and its
/// trailing close button.
const double clideInsetStandard = 8;

/// Text-content padding. Used as the leading horizontal padding of
/// text-bearing controls (tab title left padding, list-item gutter).
const double clideInsetText = 12;

// ---------------------------------------------------------------------------
// Gaps — distance between siblings
// ---------------------------------------------------------------------------

/// Tight gap between row segments inside a control.
const double clideGapTight = 4;

/// Standard gap between sibling controls (between a title and an
/// action icon, between two list items in a flex row).
const double clideGapStandard = 8;

/// Section internal gap (between a section header and its first row).
const double clideGapSection = 14;

/// Section gap (between two sections in a stack).
const double clideGapSectionLarge = 20;

/// Major gap between large blocks (between two columns in a row,
/// between header and content card).
const double clideGapMajor = 24;

/// Welcome-screen-style gap between the two centered columns.
const double clideGapColumn = 56;

// ---------------------------------------------------------------------------
// Sizes — control dimensions
// ---------------------------------------------------------------------------

/// Micro icon glyph (close ×, dropdown chevron when paired with text).
const double clideIconMicro = 10;

/// Caption-row icon (status bar, sidebar inline icons).
const double clideIconCaption = 13;

/// Standard inline icon (icon rail, action buttons).
const double clideIconStandard = 14;

/// Hit-target outer container around a micro icon. Provides hover
/// background and a comfortable click area; the icon centers inside.
const double clideIconHitTarget = 16;

/// Emphatic icon (standalone affordances, primary action glyphs).
const double clideIconEmphatic = 18;

/// Standard control height (tab, button, list row).
const double clideControlHeight = 28;
