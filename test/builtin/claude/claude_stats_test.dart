import 'dart:convert';

import 'package:clide/builtin/claude/src/claude_stats.dart';
import 'package:test/test.dart';

void main() {
  group('parseClaudeStats', () {
    test('parses daily activity, latest day, and lifetime totals', () {
      final json = jsonEncode({
        'version': 3,
        'lastComputedDate': '2026-05-22',
        'dailyActivity': [
          {'date': '2026-05-01', 'messageCount': 100, 'sessionCount': 2, 'toolCallCount': 30},
          {'date': '2026-05-22', 'messageCount': 250, 'sessionCount': 5, 'toolCallCount': 80},
        ],
      });
      final s = parseClaudeStats(json);
      expect(s.lastComputed, '2026-05-22');
      expect(s.activeDays, 2);
      expect(s.latest!.date, '2026-05-22'); // most recent, not last in array
      expect(s.latest!.messageCount, 250);
      expect(s.lifetimeMessages, 350);
      expect(s.lifetimeSessions, 7);
      expect(s.lifetimeToolCalls, 110);
    });

    test('picks the latest day regardless of array order', () {
      final json = jsonEncode({
        'dailyActivity': [
          {'date': '2026-05-22', 'messageCount': 1, 'sessionCount': 1, 'toolCallCount': 1},
          {'date': '2026-05-02', 'messageCount': 9, 'sessionCount': 9, 'toolCallCount': 9},
        ],
      });
      expect(parseClaudeStats(json).latest!.date, '2026-05-22');
    });

    test('missing counts default to zero', () {
      final json = jsonEncode({
        'dailyActivity': [
          {'date': '2026-05-22'},
        ],
      });
      final s = parseClaudeStats(json);
      expect(s.latest!.messageCount, 0);
      expect(s.lifetimeToolCalls, 0);
    });

    test('malformed or empty input yields empty stats', () {
      expect(parseClaudeStats('{ not json').daily, isEmpty);
      expect(parseClaudeStats('[]').daily, isEmpty);
      expect(parseClaudeStats('{}').latest, isNull);
    });
  });
}
