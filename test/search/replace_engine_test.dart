/// Tests for the search-and-replace engine (T-53, per D-79).
library;

import 'dart:io';

import 'package:clide/src/files/ignore.dart';
import 'package:clide/src/search/match.dart';
import 'package:clide/src/search/replace_engine.dart';
import 'package:test/test.dart';

void main() {
  group('applyToText', () {
    test('literal replacement counts and substitutes', () {
      final r = applyToText('foo foo bar', const SearchQuery(pattern: 'foo'), 'X');
      expect(r.text, 'X X bar');
      expect(r.count, 2);
    });

    test('literal is case-sensitive by default, case-insensitive on request', () {
      expect(applyToText('Foo foo', const SearchQuery(pattern: 'foo'), 'X').count, 1);
      expect(applyToText('Foo foo', const SearchQuery(pattern: 'foo', ignoreCase: true), 'X').count, 2);
    });

    test(r'literal replacement does not expand $ references', () {
      final r = applyToText('foo', const SearchQuery(pattern: 'foo'), r'$1-lit');
      expect(r.text, r'$1-lit');
    });

    test('regex replacement expands capture groups', () {
      final r = applyToText('alpha beta', const SearchQuery(pattern: r'(\w+) (\w+)', regex: true), r'$2 $1');
      expect(r.text, 'beta alpha');
      expect(r.count, 1);
    });

    test(r'regex $& is the whole match and $$ is a literal dollar', () {
      final r = applyToText('x=1', const SearchQuery(pattern: r'\d', regex: true), r'$$$&');
      expect(r.text, r'x=$1');
    });

    test('no match leaves text unchanged with count 0', () {
      final r = applyToText('abc', const SearchQuery(pattern: 'zzz'), 'X');
      expect(r.text, 'abc');
      expect(r.count, 0);
    });

    test('empty pattern is a no-op', () {
      final r = applyToText('abc', const SearchQuery(pattern: ''), 'X');
      expect(r.count, 0);
    });
  });

  group('computeReplacements', () {
    late Directory root;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('clide-replace-');
      File('${root.path}/a.dart').writeAsStringSync('final foo = 1;\nfinal bar = foo;\n');
      File('${root.path}/b.txt').writeAsStringSync('no hits\n');
    });
    tearDown(() async => root.delete(recursive: true));

    test('reports changed files with per-line before/after edits', () async {
      final r = await computeReplacements(
        root: root,
        ignore: IgnoreSet([]),
        query: const SearchQuery(pattern: 'foo'),
        replacement: 'baz',
      );
      expect(r, hasLength(1));
      final fr = r.single;
      expect(fr.path, 'a.dart');
      expect(fr.count, 2);
      expect(fr.edits, hasLength(2));
      expect(fr.edits.first.before, 'final foo = 1;');
      expect(fr.edits.first.after, 'final baz = 1;');
    });

    test('files with no match are omitted', () async {
      final r = await computeReplacements(
        root: root,
        ignore: IgnoreSet([]),
        query: const SearchQuery(pattern: 'foo'),
        replacement: 'baz',
      );
      expect(r.any((f) => f.path == 'b.txt'), isFalse);
    });

    test('honours the ignore set', () async {
      final r = await computeReplacements(
        root: root,
        ignore: IgnoreSet.parse(const ['*.dart\n']),
        query: const SearchQuery(pattern: 'foo'),
        replacement: 'baz',
      );
      expect(r, isEmpty);
    });

    test('binary files are skipped', () async {
      File('${root.path}/blob.bin').writeAsBytesSync([0x66, 0x6f, 0x6f, 0x00, 0x66, 0x6f, 0x6f]);
      final r = await computeReplacements(
        root: root,
        ignore: IgnoreSet([]),
        query: const SearchQuery(pattern: 'foo'),
        replacement: 'baz',
      );
      expect(r.any((f) => f.path == 'blob.bin'), isFalse);
    });

    // T-364: the globs were accepted and silently dropped — replace touched
    // files the equivalent search would never have matched.
    test('include glob restricts replacement to matching files', () async {
      File('${root.path}/c.txt').writeAsStringSync('foo here too\n');
      final r = await computeReplacements(
        root: root,
        ignore: IgnoreSet([]),
        query: const SearchQuery(pattern: 'foo', include: ['*.dart']),
        replacement: 'baz',
      );
      expect(r.map((f) => f.path).toList(), ['a.dart']);
    });

    test('exclude glob is honored', () async {
      File('${root.path}/c.txt').writeAsStringSync('foo here too\n');
      final r = await computeReplacements(
        root: root,
        ignore: IgnoreSet([]),
        query: const SearchQuery(pattern: 'foo', exclude: ['*.dart']),
        replacement: 'baz',
      );
      expect(r.map((f) => f.path).toList(), ['c.txt']);
    });
  });

  group('rewriteFileContent', () {
    late Directory root;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('clide-rewrite-');
      File('${root.path}/a.dart').writeAsStringSync('foo and foo\n');
    });
    tearDown(() async => root.delete(recursive: true));

    test('returns the rewritten content', () {
      final out = rewriteFileContent(root.absolute.path, 'a.dart', const SearchQuery(pattern: 'foo'), 'X');
      expect(out, 'X and X\n');
    });

    test('returns null when nothing changes', () {
      final out = rewriteFileContent(root.absolute.path, 'a.dart', const SearchQuery(pattern: 'zzz'), 'X');
      expect(out, isNull);
    });

    test('ReplacementEdit + FileReplacement round-trip JSON', () {
      const fr = FileReplacement(
        path: 'a.dart',
        count: 1,
        edits: [ReplacementEdit(line: 2, before: 'a', after: 'b')],
      );
      final back = FileReplacement.fromJson(fr.toJson());
      expect(back.path, 'a.dart');
      expect(back.count, 1);
      expect(back.edits.single.line, 2);
      expect(back.edits.single.after, 'b');
    });
  });
}
