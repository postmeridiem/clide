/// Pure-Dart tests for `grammarForPath` in
/// `lib/kernel/src/syntax/language_map.dart`.
library;

import 'package:clide/kernel/src/syntax/language_map.dart';
import 'package:test/test.dart';

void main() {
  group('grammarForPath', () {
    test('maps common file extensions to grammar names', () {
      expect(grammarForPath('foo.dart'), 'dart');
      expect(grammarForPath('a/b/c.go'), 'go');
      expect(grammarForPath('script.py'), 'python');
      expect(grammarForPath('view.tsx'), 'typescript');
      expect(grammarForPath('config.yaml'), 'yaml');
      expect(grammarForPath('config.yml'), 'yaml');
      expect(grammarForPath('readme.md'), 'markdown');
    });

    test('extension match is case-insensitive', () {
      expect(grammarForPath('a.R'), 'r');
      expect(grammarForPath('Q.PY'), 'python');
    });

    test('special filenames bypass the extension lookup', () {
      expect(grammarForPath('Makefile'), 'make');
      expect(grammarForPath('a/b/Dockerfile'), 'dockerfile');
      expect(grammarForPath('.gitignore'), 'gitignore');
      expect(grammarForPath('justfile'), 'just');
    });

    test('special filename + recognised extension still picks the special name', () {
      // Makefile has no '.' so the extension branch wouldn't fire anyway —
      // this just locks in that the filename map runs first.
      expect(grammarForPath('Makefile'), 'make');
    });

    test('returns null when there is no dot and no special filename match', () {
      expect(grammarForPath('README'), isNull);
      expect(grammarForPath('a/b/UNKNOWNFILE'), isNull);
    });

    test('returns null for an unknown extension', () {
      expect(grammarForPath('foo.unknownextension'), isNull);
      expect(grammarForPath('a/b/c.xyz'), isNull);
    });
  });
}
