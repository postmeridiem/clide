/// Tests for `walkFiles` — the recursive, ignore-pruned, capped
/// workspace file walk behind `files.walk` and the search engine.
library;

import 'dart:io';

import 'package:clide/src/files/ignore.dart';
import 'package:clide/src/files/listing.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('clide-walk-');
    File('${root.path}/README.md').writeAsStringSync('a');
    File('${root.path}/pubspec.yaml').writeAsStringSync('b');
    Directory('${root.path}/lib/src').createSync(recursive: true);
    File('${root.path}/lib/main.dart').writeAsStringSync('c');
    File('${root.path}/lib/src/util.dart').writeAsStringSync('d');
    Directory('${root.path}/build').createSync();
    File('${root.path}/build/output.bin').writeAsStringSync('e');
  });
  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('walks recursively, returns files sorted by path', () async {
    final r = await walkFiles(root: root, ignore: IgnoreSet([]));
    expect(r.truncated, isFalse);
    expect(r.files.map((e) => e.path).toList(), ['README.md', 'build/output.bin', 'lib/main.dart', 'lib/src/util.dart', 'pubspec.yaml']);
  });

  test('prunes ignored directories (build/ via builtin ignore)', () async {
    final r = await walkFiles(root: root, ignore: IgnoreSet.builtin());
    final paths = r.files.map((e) => e.path).toList();
    expect(paths, isNot(contains('build/output.bin')));
    expect(paths, containsAll(['README.md', 'lib/main.dart', 'lib/src/util.dart']));
  });

  test('emits only files, never directory entries', () async {
    final r = await walkFiles(root: root, ignore: IgnoreSet([]));
    expect(r.files.every((e) => !e.isDirectory), isTrue);
  });

  test('respects the maxFiles cap and flags truncation', () async {
    final r = await walkFiles(root: root, ignore: IgnoreSet([]), maxFiles: 2);
    expect(r.truncated, isTrue);
    expect(r.files, hasLength(2));
  });

  test('an empty workspace yields no files and is not truncated', () async {
    final empty = await Directory.systemTemp.createTemp('clide-walk-empty-');
    addTearDown(() => empty.deleteSync(recursive: true));
    final r = await walkFiles(root: empty, ignore: IgnoreSet([]));
    expect(r.files, isEmpty);
    expect(r.truncated, isFalse);
  });
}
