import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('claude session naming', () {
    test('primary name is deterministic per repo path', () {
      final a = primarySessionName('/home/me/clide');
      final b = primarySessionName('/home/me/clide');
      expect(a, b);
      expect(a, startsWith('clide-claude-'));
    });

    test('different repos yield different primaries', () {
      final a = primarySessionName('/home/me/clide');
      final b = primarySessionName('/home/me/other');
      expect(a, isNot(b));
    });

    test('secondary names carry the N suffix', () {
      final p = primarySessionName('/home/me/clide');
      final s1 = secondarySessionName('/home/me/clide', 1);
      final s2 = secondarySessionName('/home/me/clide', 2);
      expect(s1, '$p-1');
      expect(s2, '$p-2');
    });
  });
}
