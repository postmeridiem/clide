/// Minimum dimension handed to any PTY backend.
///
/// A 1-column ConPTY makes the Windows conhost spin emitting CRLF forever
/// (microsoft/terminal#19922), and a 0 in either axis is invalid on both
/// platforms. Every backend clamps its spawn + resize through this, so a
/// degenerate size from the UI — a pane measured at zero width during a
/// transient layout pass — can never wedge a child. The floor (2) is below
/// any real terminal, so the clamp is invisible in normal use.
library;

/// Smallest column/row count a PTY backend will accept.
const int minPtyDimension = 2;

/// Clamp a column or row count up to [minPtyDimension].
int clampPtyDimension(int value) => value < minPtyDimension ? minPtyDimension : value;
