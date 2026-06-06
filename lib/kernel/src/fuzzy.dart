/// Subsequence fuzzy matching, shared by the command palette and the
/// quick-open file finder. Pure Dart (no Flutter) so it's reusable across
/// isolates and trivially unit-testable.
library;

/// Returns null when [query]'s characters don't appear in order within
/// [text]; otherwise a score where **lower is better** — contiguous, early
/// matches score best; gaps between matched chars and a late first match add
/// penalty. Callers that want case-insensitive matching should lowercase both
/// arguments first.
int? fuzzyScore(String text, String query) {
  if (query.isEmpty) return 0;
  var ti = 0;
  var qi = 0;
  var score = 0;
  int? last;
  while (ti < text.length && qi < query.length) {
    if (text.codeUnitAt(ti) == query.codeUnitAt(qi)) {
      score += last == null ? ti : (ti - last - 1);
      last = ti;
      qi++;
    }
    ti++;
  }
  if (qi != query.length) return null;
  return score;
}
