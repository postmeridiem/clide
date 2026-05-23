import 'package:clide/builtin/claude/src/slash_commands.dart';
import 'package:test/test.dart';

void main() {
  group('slashCommandToken', () {
    test('extracts the command word from single-line slash input', () {
      expect(slashCommandToken('/model sonnet'), 'model');
      expect(slashCommandToken('/whats-next'), 'whats-next');
      expect(slashCommandToken('/foo\tbar'), 'foo');
    });

    test('returns null for non-command input', () {
      expect(slashCommandToken('hello'), isNull);
      expect(slashCommandToken(' /leading-space'), isNull);
      expect(slashCommandToken('/'), isNull); // empty token
      expect(slashCommandToken('/foo\nbar'), isNull); // multi-line
    });
  });

  group('isKnownSlashCommand', () {
    const known = {'model', 'clear', 'whats-next'};

    test('true only when the token is a recognised command', () {
      expect(isKnownSlashCommand('/model opus', known), isTrue);
      expect(isKnownSlashCommand('/whats-next', known), isTrue);
      expect(isKnownSlashCommand('/unknown-cmd', known), isFalse);
    });

    test('a path-like leading slash is not a command (stays literal)', () {
      expect(isKnownSlashCommand('/tmp/foo.log has errors', known), isFalse);
    });

    test('non-slash and multi-line input is never a command', () {
      expect(isKnownSlashCommand('hello world', known), isFalse);
      expect(isKnownSlashCommand('/clear\nand more', {'clear'}), isFalse);
    });
  });

  group('clideOwnedCommand', () {
    test('recognises /clear as clide-owned', () {
      expect(clideOwnedCommand('/clear'), 'clear');
      expect(clideOwnedCommand('/clear '), 'clear');
    });

    test('returns null for commands clide forwards to Claude', () {
      expect(clideOwnedCommand('/model sonnet'), isNull);
      expect(clideOwnedCommand('/compact'), isNull);
      expect(clideOwnedCommand('not a command'), isNull);
      expect(clideOwnedCommand('/clearairspace'), isNull); // token must be exactly "clear"
    });
  });

  group('activeSlashQuery', () {
    test('matches a slash token at the cursor, including inline', () {
      expect(activeSlashQuery('/mod', 4), const SlashQuery(start: 0, query: 'mod'));
      expect(activeSlashQuery('go /mo', 6), const SlashQuery(start: 3, query: 'mo'));
      expect(activeSlashQuery('/', 1), const SlashQuery(start: 0, query: ''));
    });

    test('no match for paths, post-space, or non-slash runs', () {
      expect(activeSlashQuery('a/b', 3), isNull); // slash mid-token (path)
      expect(activeSlashQuery('/model sonnet', 13), isNull); // closed after space
      expect(activeSlashQuery('hello', 5), isNull);
      expect(activeSlashQuery('/model ', 7), isNull); // cursor right after space
    });

    test('uses the cursor, not the end of text', () {
      // Cursor sits right after "/mo" inside "/model".
      expect(activeSlashQuery('/model', 3), const SlashQuery(start: 0, query: 'mo'));
    });
  });

  group('filterSlashCommands', () {
    const commands = ['model', 'memory', 'clear', 'compact', 'context'];

    test('prefix-filters case-insensitively and sorts', () {
      expect(filterSlashCommands('co', commands), ['compact', 'context']);
      expect(filterSlashCommands('M', commands), ['memory', 'model']);
    });

    test('empty query returns all (sorted, capped)', () {
      expect(filterSlashCommands('', commands, limit: 3), ['clear', 'compact', 'context']);
    });

    test('de-duplicates', () {
      expect(filterSlashCommands('p', ['pql', 'pql', 'plan']), ['plan', 'pql']);
    });
  });

  group('completeSlash', () {
    test('replaces the token with /command and a trailing space', () {
      const q = SlashQuery(start: 0, query: 'mo');
      final r = completeSlash('/mo', q, 'model');
      expect(r.text, '/model ');
      expect(r.cursor, 7);
    });

    test('completes an inline token without disturbing surrounding text', () {
      const q = SlashQuery(start: 3, query: 'mo');
      final r = completeSlash('go /mo now', q, 'model');
      expect(r.text, 'go /model  now');
      expect(r.cursor, 10);
    });
  });
}
