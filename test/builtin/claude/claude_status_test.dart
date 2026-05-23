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
  });
}
