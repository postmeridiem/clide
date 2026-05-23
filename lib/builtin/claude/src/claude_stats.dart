/// Reads Claude Code's `~/.claude/stats-cache.json` — per-day activity
/// (message / session / tool-call counts) — for the meta sidebar (T-141).
/// Flutter-free so it unit-tests under `dart test`. This is activity, not the
/// account budget; the budget isn't programmatically exposed (see
/// project memory / GitHub anthropics/claude-code#44328).
library;

import 'dart:convert';

class DailyActivity {
  const DailyActivity({
    required this.date,
    required this.messageCount,
    required this.sessionCount,
    required this.toolCallCount,
  });

  final String date; // "YYYY-MM-DD" (sorts chronologically as a string)
  final int messageCount;
  final int sessionCount;
  final int toolCallCount;
}

class ClaudeStats {
  const ClaudeStats({this.lastComputed, this.daily = const []});

  final String? lastComputed;
  final List<DailyActivity> daily;

  /// The most recent day on record, or null if there's no activity.
  DailyActivity? get latest {
    if (daily.isEmpty) return null;
    return daily.reduce((a, b) => a.date.compareTo(b.date) >= 0 ? a : b);
  }

  int get activeDays => daily.length;
  int get lifetimeMessages => daily.fold(0, (a, d) => a + d.messageCount);
  int get lifetimeSessions => daily.fold(0, (a, d) => a + d.sessionCount);
  int get lifetimeToolCalls => daily.fold(0, (a, d) => a + d.toolCallCount);
}

/// Parse the stats-cache JSON. Returns empty stats on any malformed input —
/// the sidebar degrades to "no activity" rather than throwing.
ClaudeStats parseClaudeStats(String jsonStr) {
  Object? j;
  try {
    j = jsonDecode(jsonStr);
  } catch (_) {
    return const ClaudeStats();
  }
  if (j is! Map) return const ClaudeStats();
  final daily = <DailyActivity>[];
  final da = j['dailyActivity'];
  if (da is List) {
    for (final e in da) {
      if (e is! Map) continue;
      daily.add(DailyActivity(
        date: '${e['date']}',
        messageCount: _int(e['messageCount']),
        sessionCount: _int(e['sessionCount']),
        toolCallCount: _int(e['toolCallCount']),
      ));
    }
  }
  return ClaudeStats(lastComputed: j['lastComputedDate'] as String?, daily: daily);
}

int _int(Object? v) => v is num ? v.toInt() : 0;
