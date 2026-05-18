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

    test('a HOME-relative path collapses the HOME prefix in the slug', () {
      // Forces the `p.startsWith(home)` branch.
      final home = const String.fromEnvironment('HOME');
      // Use a path we know lives under the platform HOME so the branch fires.
      // In test environments HOME is set; the path /tmp may or may not be
      // under it. Use a synthesized HOME path so the assert holds regardless.
      final fake = '${home.isEmpty ? '/home/test' : home}/projects/clide';
      final name = primarySessionName(fake);
      expect(name, contains('projects-clide'));
    });

    test('path of only "/" slugifies to "root"', () {
      // Exercises the "strip leading/trailing '-' then fall back" branch.
      expect(primarySessionName('/'), 'clide-claude-root');
    });

    test('path longer than the slug cap hashes to 8 hex chars', () {
      final long = '/${'segment/' * 30}leaf';
      final name = primarySessionName(long);
      // Hash form: clide-claude-<8 hex>.
      expect(name, matches(RegExp(r'^clide-claude-[0-9a-f]{8}$')));
    });

    test('the same long path produces a stable hash', () {
      final long = '/${'a/' * 200}';
      expect(primarySessionName(long), primarySessionName(long));
    });
  });
}
