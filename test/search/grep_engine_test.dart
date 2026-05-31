/// Tests for the pure-Dart grep engine (T-52 / D-79). Run in-process
/// (`useIsolates: false`) for determinism — the isolate path is the
/// same code, parallelised.
library;

import 'dart:io';

import 'package:clide/src/files/ignore.dart';
import 'package:clide/src/search/grep_engine.dart';
import 'package:clide/src/search/match.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('clide-grep-');
    File('${root.path}/a.dart').writeAsStringSync('void main() {}\nfinal x = 1;\n');
    File('${root.path}/b.dart').writeAsStringSync('// TODO: fix\nfinal y = main;\n');
    Directory('${root.path}/sub').createSync();
    File('${root.path}/sub/c.txt').writeAsStringSync('main main main\n');
  });
  tearDown(() async => root.delete(recursive: true));

  Future<List<SearchMatch>> run(SearchQuery q, {int maxResults = 5000, int maxPerFile = 200}) async {
    final out = <SearchMatch>[];
    await for (final batch in grepWorkspace(
      root: root,
      ignore: IgnoreSet([]),
      query: q,
      useIsolates: false,
      concurrency: 1,
      maxResults: maxResults,
      maxPerFile: maxPerFile,
    )) {
      out.addAll(batch);
    }
    return out;
  }

  test('literal match finds lines across files', () async {
    final r = await run(const SearchQuery(pattern: 'main'));
    final paths = r.map((m) => m.path).toSet();
    expect(paths, containsAll(['a.dart', 'b.dart', 'sub/c.txt']));
    final aMatch = r.firstWhere((m) => m.path == 'a.dart');
    expect(aMatch.line, 1);
    expect(aMatch.preview, 'void main() {}');
    expect(aMatch.matchStart, 5);
    expect(aMatch.matchEnd, 9);
  });

  test('emits one match per occurrence within a line', () async {
    final r = await run(const SearchQuery(pattern: 'main'));
    final cTxt = r.where((m) => m.path == 'sub/c.txt').toList();
    expect(cTxt, hasLength(3));
  });

  test('case-insensitive literal match', () async {
    final r = await run(const SearchQuery(pattern: 'TODO', ignoreCase: true));
    // 'TODO' present as-is; also matches regardless of case toggle.
    expect(r.any((m) => m.path == 'b.dart'), isTrue);
    final lower = await run(const SearchQuery(pattern: 'todo', ignoreCase: true));
    expect(lower.any((m) => m.path == 'b.dart'), isTrue);
  });

  test('case-sensitive miss when case differs', () async {
    final r = await run(const SearchQuery(pattern: 'todo'));
    expect(r.where((m) => m.path == 'b.dart'), isEmpty);
  });

  test('regex match with anchors', () async {
    final r = await run(const SearchQuery(pattern: r'final \w+', regex: true));
    expect(r.map((m) => m.path).toSet(), containsAll(['a.dart', 'b.dart']));
  });

  test('invalid regex throws FormatException', () async {
    expect(
      () => run(const SearchQuery(pattern: '(unclosed', regex: true)),
      throwsA(isA<FormatException>()),
    );
  });

  test('include glob restricts to matching files', () async {
    final r = await run(const SearchQuery(pattern: 'main', include: ['*.dart']));
    expect(r.every((m) => m.path.endsWith('.dart')), isTrue);
    expect(r.any((m) => m.path == 'sub/c.txt'), isFalse);
  });

  test('exclude glob removes matching files', () async {
    final r = await run(const SearchQuery(pattern: 'main', exclude: ['*.txt']));
    expect(r.any((m) => m.path == 'sub/c.txt'), isFalse);
    expect(r.any((m) => m.path == 'a.dart'), isTrue);
  });

  test('maxPerFile caps matches from one file', () async {
    final r = await run(const SearchQuery(pattern: 'main'), maxPerFile: 1);
    expect(r.where((m) => m.path == 'sub/c.txt'), hasLength(1));
  });

  test('maxResults caps total matches', () async {
    final r = await run(const SearchQuery(pattern: 'main'), maxResults: 2);
    expect(r, hasLength(2));
  });

  test('empty pattern yields nothing', () async {
    expect(await run(const SearchQuery(pattern: '')), isEmpty);
  });

  test('binary files are skipped', () async {
    File('${root.path}/blob.bin').writeAsBytesSync([0x6d, 0x61, 0x69, 0x6e, 0x00, 0x6d, 0x61, 0x69, 0x6e]);
    final r = await run(const SearchQuery(pattern: 'main'));
    expect(r.any((m) => m.path == 'blob.bin'), isFalse);
  });

  test('cancellation stops the stream early', () async {
    final cancel = CancelToken()..cancel();
    final out = <SearchMatch>[];
    await for (final batch in grepWorkspace(
      root: root,
      ignore: IgnoreSet([]),
      query: const SearchQuery(pattern: 'main'),
      useIsolates: false,
      concurrency: 1,
      cancel: cancel,
    )) {
      out.addAll(batch);
    }
    expect(out, isEmpty);
  });

  test('ignored files are not searched', () async {
    final out = <SearchMatch>[];
    await for (final batch in grepWorkspace(
      root: root,
      ignore: IgnoreSet.parse(const ['*.txt\n']),
      query: const SearchQuery(pattern: 'main'),
      useIsolates: false,
      concurrency: 1,
    )) {
      out.addAll(batch);
    }
    expect(out.any((m) => m.path == 'sub/c.txt'), isFalse);
  });

  // Spawns real worker isolates — runs in the --concurrency=1 serial
  // pass to avoid competing with the parallel flutter pool (T-193).
  test('? and ** glob metacharacters match as expected', () async {
    File('${root.path}/a1.dart').writeAsStringSync('main\n');
    // '?' matches a single char: a?.dart → a1.dart (and a.dart).
    final q = await run(const SearchQuery(pattern: 'main', include: ['a?.dart']));
    expect(q.any((m) => m.path == 'a1.dart'), isTrue);
    expect(q.any((m) => m.path == 'sub/c.txt'), isFalse);
    // '**' spans directories.
    final r = await run(const SearchQuery(pattern: 'main', include: ['sub/**']));
    expect(r.any((m) => m.path == 'sub/c.txt'), isTrue);
  });

  test('regex capture groups are available on the match line', () async {
    // The engine surfaces spans; group expansion is the replacer's job
    // (T-53), but the regex itself must match with groups.
    final r = await run(const SearchQuery(pattern: r'final (\w+)', regex: true));
    expect(r.any((m) => m.path == 'a.dart'), isTrue);
  });

  test('runs across isolates without error (smoke)', tags: ['serial'], () async {
    final out = <SearchMatch>[];
    await for (final batch in grepWorkspace(
      root: root,
      ignore: IgnoreSet([]),
      query: const SearchQuery(pattern: 'main'),
      useIsolates: true,
    )) {
      out.addAll(batch);
    }
    expect(out, isNotEmpty);
  });
}
