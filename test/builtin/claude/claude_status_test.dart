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
      const s = SessionStatus(model: 'claude-opus-4-7', permissionMode: 'default', contextTokens: 21000, contextWindow: 1000000, cost: 0.05);
      final line = formatStatusLine(s);
      expect(line, contains('opus 4.7'));
      expect(line, contains('default'));
      expect(line, contains('21k / 1.0M ctx'));
      expect(line, contains('\$0.05'));
    });
  });

  group('nextSafePermissionMode (T-226)', () {
    test('cycles the safe trio and wraps', () {
      expect(nextSafePermissionMode('default'), 'acceptEdits');
      expect(nextSafePermissionMode('acceptEdits'), 'plan');
      expect(nextSafePermissionMode('plan'), 'default');
    });

    test('bypassPermissions / unknown restarts at default (never cycles into bypass)', () {
      expect(nextSafePermissionMode('bypassPermissions'), 'default');
      expect(nextSafePermissionMode('whatever'), 'default');
      expect(kSafePermissionCycle, isNot(contains('bypassPermissions')));
    });
  });

  group('nextPermissionMode (T-510)', () {
    test('cycles the full list including bypass and wraps', () {
      expect(nextPermissionMode('default'), 'acceptEdits');
      expect(nextPermissionMode('acceptEdits'), 'plan');
      expect(nextPermissionMode('plan'), 'bypassPermissions');
      expect(nextPermissionMode('bypassPermissions'), 'default');
    });

    test('unknown restarts at default', () {
      expect(nextPermissionMode('whatever'), 'default');
      expect(kFullPermissionCycle, contains('bypassPermissions'));
    });
  });

  group('statusSegmentsAroundMode (T-226)', () {
    test('splits model (leading) from ctx/cost/rate (trailing), mode excluded', () {
      const s = SessionStatus(model: 'claude-opus-4-7', permissionMode: 'plan', contextTokens: 21000, cost: 0.05);
      final seg = statusSegmentsAroundMode(s);
      expect(seg.leading, 'opus 4.7');
      expect(seg.trailing, contains('21k ctx'));
      expect(seg.trailing, contains('\$0.05'));
      expect(seg.trailing, isNot(contains('plan'))); // mode is its own badge
    });

    test('nulls when nothing to show on a side', () {
      final seg = statusSegmentsAroundMode(const SessionStatus(permissionMode: 'default'));
      expect(seg.leading, isNull);
      expect(seg.trailing, isNull);
    });
  });

  group('parseUsageText (T-415)', () {
    // The probed 2.1.175 /usage response shape.
    const probed =
        'You are currently using your subscription to power your Claude Code usage\n'
        '\n'
        'Current session: 15% used · resets Jun 12, 3:39pm (Europe/Amsterdam)\n'
        'Current week (all models): 53% used · resets Jun 15, 6:59pm (Europe/Amsterdam)\n'
        'Current week (Sonnet only): 0% used';

    test('parses the probed response, stripping timezone parentheticals', () {
      final u = parseUsageText(probed)!;
      expect(u.session, '15% used · resets Jun 12, 3:39pm');
      expect(u.week, '53% used · resets Jun 15, 6:59pm');
      expect(u.weekSonnet, '0% used');
    });

    test('tolerates missing lines', () {
      final u = parseUsageText('Current session: 9% used')!;
      expect(u.session, '9% used');
      expect(u.week, isNull);
      expect(u.weekSonnet, isNull);
    });

    test('non-usage text parses to null', () {
      expect(parseUsageText("/effort isn't available in this environment."), isNull);
      expect(parseUsageText('plain prose'), isNull);
    });
  });
}
