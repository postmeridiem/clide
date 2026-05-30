import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The tmux-slug functions (primarySessionName / secondarySessionName) are
  // retired as public API (D-77 / T-167). The UUID derivation is kept because
  // `primarySessionId` still deterministically derives its UUID from the old
  // slug (private) so existing transcripts survive the migration.

  group('claude session ids (T-146)', () {
    final uuidRe = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

    test('primary id is a valid v4-format UUID', () {
      expect(primarySessionId('/home/me/clide'), matches(uuidRe));
    });

    test('primary id is deterministic per repo (resumes across restarts)', () {
      expect(primarySessionId('/home/me/clide'), primarySessionId('/home/me/clide'));
    });

    test('different repos get different primary ids', () {
      expect(primarySessionId('/home/me/clide'), isNot(primarySessionId('/home/me/other')));
    });

    test('fresh ids are valid UUIDs and unique per call (clean secondaries)', () {
      final a = freshSessionId();
      final b = freshSessionId();
      expect(a, matches(uuidRe));
      expect(b, matches(uuidRe));
      expect(a, isNot(b));
    });
  });

  group('claudeLaunchArgs (T-161 / T-167)', () {
    test('resumes an existing session with --resume, not --session-id', () {
      // --session-id refuses an existing id ("already in use"), so resuming
      // (transcript on disk) must use --resume (D-77).
      expect(claudeLaunchArgs('abc', resume: true), ['--resume', 'abc']);
    });

    test('creates a new session with --session-id', () {
      expect(claudeLaunchArgs('abc', resume: false), ['--session-id', 'abc']);
    });

    test('resume flag controls the verb — same id, different verb', () {
      const id = '11111111-1111-4111-8111-111111111111';
      final fresh = claudeLaunchArgs(id, resume: false);
      final resumed = claudeLaunchArgs(id, resume: true);
      expect(fresh.first, '--session-id');
      expect(resumed.first, '--resume');
      expect(fresh.last, id);
      expect(resumed.last, id);
    });
  });

  group('forkSessionArgs (T-172)', () {
    const sourceId = 'aaaa1111-1111-4111-8111-111111111111';

    test('fork args lead with --resume then the source id', () {
      final args = forkSessionArgs(sourceId);
      expect(args[0], '--resume');
      expect(args[1], sourceId);
    });

    test('fork args include --fork-session to diverge without touching the original', () {
      final args = forkSessionArgs(sourceId);
      expect(args, contains('--fork-session'));
    });

    test('fork args contain exactly three elements', () {
      // [--resume, <sourceId>, --fork-session] — no --session-id so claude
      // assigns its own new session id (the branch).
      expect(forkSessionArgs(sourceId), hasLength(3));
    });

    test('fork args do not contain --session-id', () {
      expect(forkSessionArgs(sourceId), isNot(contains('--session-id')));
    });
  });
}
