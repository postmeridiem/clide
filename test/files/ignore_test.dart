import 'package:clide/clide.dart';
import 'package:test/test.dart';

void main() {
  group('IgnorePattern.parse', () {
    test('blank + comment lines return null', () {
      expect(IgnorePattern.parse(''), isNull);
      expect(IgnorePattern.parse('   '), isNull);
      expect(IgnorePattern.parse('# comment'), isNull);
    });

    test('directory-only detected', () {
      final p = IgnorePattern.parse('build/');
      expect(p, isNotNull);
      expect(p!.directoryOnly, isTrue);
    });

    test('negation detected', () {
      final p = IgnorePattern.parse('!keep.txt');
      expect(p!.negated, isTrue);
    });

    test('anchored detected', () {
      final p = IgnorePattern.parse('/root-only.txt');
      expect(p!.anchored, isTrue);
    });
  });

  group('IgnoreSet', () {
    test('matches unanchored name at any depth', () {
      final s = IgnoreSet.parse(const ['node_modules/\n*.log\n']);
      expect(s.isIgnored('node_modules', isDirectory: true), isTrue);
      expect(s.isIgnored('a/b/node_modules', isDirectory: true), isTrue);
      expect(s.isIgnored('a.log', isDirectory: false), isTrue);
      expect(s.isIgnored('deep/nested/foo.log', isDirectory: false), isTrue);
    });

    test('directory-only pattern does not match files', () {
      final s = IgnoreSet.parse(const ['cache/\n']);
      expect(s.isIgnored('cache', isDirectory: true), isTrue);
      expect(s.isIgnored('cache', isDirectory: false), isFalse);
    });

    test('anchored pattern stays at the root', () {
      final s = IgnoreSet.parse(const ['/config.yaml\n']);
      expect(s.isIgnored('config.yaml', isDirectory: false), isTrue);
      expect(s.isIgnored('app/config.yaml', isDirectory: false), isFalse);
    });

    test('later pattern wins — negation unignores', () {
      final s = IgnoreSet.parse(const ['*.log\n!keep.log\n']);
      expect(s.isIgnored('a.log', isDirectory: false), isTrue);
      expect(s.isIgnored('keep.log', isDirectory: false), isFalse);
    });

    test('layered sets preserve order', () {
      final s = IgnoreSet.parse(const ['*.tmp\n', '!important.tmp\n']);
      expect(s.isIgnored('x.tmp', isDirectory: false), isTrue);
      expect(s.isIgnored('important.tmp', isDirectory: false), isFalse);
    });

    test('built-in set hides clide-owned dirs', () {
      final s = IgnoreSet.builtin();
      for (final d in const ['.git', '.pql', '.clide', '.dart_tool', 'build', 'node_modules']) {
        expect(s.isIgnored(d, isDirectory: true), isTrue, reason: d);
      }
      expect(s.isIgnored('lib', isDirectory: true), isFalse);
    });

    test('** crosses directory boundaries', () {
      final s = IgnoreSet.parse(const ['docs/**/*.draft.md\n']);
      expect(
        s.isIgnored('docs/deep/nested/a.draft.md', isDirectory: false),
        isTrue,
      );
      expect(s.isIgnored('docs/a.draft.md', isDirectory: false), isTrue);
      expect(s.isIgnored('other/a.draft.md', isDirectory: false), isFalse);
    });
  });
}
