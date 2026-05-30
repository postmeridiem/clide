/// Tests for the per-session status line formatting (T-145).
library;

import 'package:clide/builtin/claude/src/claude_status.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:test/test.dart';

void main() {
  group('status formatters', () {
    test('shortModelLabel strips the claude- prefix and dots the version', () {
      expect(shortModelLabel('claude-opus-4-7'), 'opus 4.7');
      expect(shortModelLabel('claude-sonnet-4-6'), 'sonnet 4.6');
      expect(shortModelLabel('weird'), 'weird');
    });

    test('permissionModeLabel humanises CC modes', () {
      expect(permissionModeLabel('acceptEdits'), 'accept-edits');
      expect(permissionModeLabel('bypassPermissions'), 'bypass');
      expect(permissionModeLabel('plan'), 'plan');
      expect(permissionModeLabel('default'), 'default');
      expect(permissionModeLabel('something-new'), 'something-new');
    });

    test('formatTokenCount uses k / M / raw', () {
      expect(formatTokenCount(500), '500');
      expect(formatTokenCount(765000), '765k');
      expect(formatTokenCount(1200000), '1.2M');
    });

    test('formatSkillsLabel pluralises and hides zero', () {
      expect(formatSkillsLabel(0), isNull);
      expect(formatSkillsLabel(1), '1 skill');
      expect(formatSkillsLabel(12), '12 skills');
    });
  });

  group('formatStatusLine', () {
    test('joins the present fields', () {
      const s = SessionStatus(model: 'claude-opus-4-7', permissionMode: 'acceptEdits', contextTokens: 21000);
      expect(formatStatusLine(s), 'opus 4.7  ·  accept-edits  ·  21k ctx');
    });

    test('omits absent fields', () {
      expect(formatStatusLine(const SessionStatus(model: 'claude-sonnet-4-6')), 'sonnet 4.6');
      expect(formatStatusLine(const SessionStatus()), '');
    });

    test('includes cost when present (T-168)', () {
      const s = SessionStatus(model: 'claude-opus-4-7', cost: 0.123);
      expect(formatStatusLine(s), contains('\$0.12'));
    });

    test('shows ctx as fraction when contextWindow is known (T-168)', () {
      const s = SessionStatus(contextTokens: 21000, contextWindow: 1000000);
      expect(formatStatusLine(s), contains('21k / 1.0M ctx'));
    });

    test('shows plain ctx count when contextWindow is absent', () {
      const s = SessionStatus(contextTokens: 21000);
      expect(formatStatusLine(s), contains('21k ctx'));
      expect(formatStatusLine(s), isNot(contains('/')));
    });

    test('includes rateLimitInfo when present (T-168)', () {
      const s = SessionStatus(rateLimitInfo: 'rate limited — resets 14:32');
      expect(formatStatusLine(s), 'rate limited — resets 14:32');
    });

    test('full status line with all fields (T-168)', () {
      const s = SessionStatus(
        model: 'claude-opus-4-7',
        permissionMode: 'default',
        contextTokens: 21000,
        contextWindow: 1000000,
        cost: 0.05,
      );
      final line = formatStatusLine(s);
      expect(line, contains('opus 4.7'));
      expect(line, contains('default'));
      expect(line, contains('21k / 1.0M ctx'));
      expect(line, contains('\$0.05'));
    });
  });
}
