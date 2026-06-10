/// Shared spacing for conversation-stream cards (T-305).
///
/// The stream has three card categories — dialog cards (speaker stripe), simple
/// cards (a single always-open item), and collapsibles ([ClideCollapserCard]).
/// They are deliberately NOT forced through one wrapper widget; instead they all
/// pull these constants so the stream reads as one consistent rhythm. Change a
/// value here and every category moves together.
library;

/// Vertical gap below each stream card (its bottom margin). Matches the rhythm
/// the prose cards established (T-282).
const double kClideCardGap = 14;

/// Corner radius for stream card frames.
const double kClideCardRadius = 4;

/// Horizontal / vertical padding inside a card header row.
const double kClideCardHeaderPadH = 10;
const double kClideCardHeaderPadV = 6;

/// Fixed width of the right-aligned counter slot in a collapser header, so the
/// count (and the status icon hard against the edge) never shift as the number
/// grows or the status appears (T-305).
const double kClideCardCounterSlotWidth = 60;
