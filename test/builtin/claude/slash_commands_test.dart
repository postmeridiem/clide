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
}
