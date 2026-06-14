/// Shared window-chrome metrics.
///
/// `hatHeight` used to live in clide_column_hat.dart; the per-column
/// `ColumnHat` widget there was dead (duplicated by the hat bar in
/// app.dart, kept alive only by a zero-coverage test) and was removed
/// in the T-385 sweep — the constant is the part the live chrome
/// (app.dart hat bar, menu bar) actually consumes (D-57).
library;

/// Height of the per-column 24px window hats (D-57).
const double hatHeight = 24;
