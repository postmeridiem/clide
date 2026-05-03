import 'dart:io';

import 'package:clide/src/git/diff.dart';
import 'package:test/test.dart';

void main() {
  group('parseDiffOutput', () {
    test('parses a simple modification', () {
      const output = '''diff --git a/file.txt b/file.txt
index abc1234..def5678 100644
--- a/file.txt
+++ b/file.txt
@@ -1,3 +1,4 @@
 line1
-line2
+line2-modified
+line3-new
 line4
''';
      final diffs = parseDiffOutput(output);
      expect(diffs, hasLength(1));
      expect(diffs.first.path, 'file.txt');
      expect(diffs.first.hunks, hasLength(1));
      expect(diffs.first.additions, 2);
      expect(diffs.first.removals, 1);
    });

    test('parses a new file', () {
      const output = '''diff --git a/new.txt b/new.txt
new file mode 100644
index 0000000..abc1234
--- /dev/null
+++ b/new.txt
@@ -0,0 +1,2 @@
+hello
+world
''';
      final diffs = parseDiffOutput(output);
      expect(diffs, hasLength(1));
      expect(diffs.first.isNew, isTrue);
      expect(diffs.first.additions, 2);
    });

    test('parses a deleted file', () {
      const output = '''diff --git a/old.txt b/old.txt
deleted file mode 100644
index abc1234..0000000
--- a/old.txt
+++ /dev/null
@@ -1,2 +0,0 @@
-hello
-world
''';
      final diffs = parseDiffOutput(output);
      expect(diffs, hasLength(1));
      expect(diffs.first.isDeleted, isTrue);
      expect(diffs.first.removals, 2);
    });

    test('parses a rename', () {
      const output = '''diff --git a/old.txt b/new.txt
similarity index 100%
rename from old.txt
rename to new.txt
''';
      final diffs = parseDiffOutput(output);
      expect(diffs, hasLength(1));
      expect(diffs.first.isRenamed, isTrue);
      expect(diffs.first.path, 'new.txt');
      expect(diffs.first.oldPath, 'old.txt');
    });

    test('parses multiple hunks', () {
      const output = '''diff --git a/multi.txt b/multi.txt
index abc..def 100644
--- a/multi.txt
+++ b/multi.txt
@@ -1,3 +1,3 @@
 line1
-old2
+new2
 line3
@@ -10,3 +10,3 @@
 line10
-old11
+new11
 line12
''';
      final diffs = parseDiffOutput(output);
      expect(diffs, hasLength(1));
      expect(diffs.first.hunks, hasLength(2));
      expect(diffs.first.hunks[0].oldStart, 1);
      expect(diffs.first.hunks[1].oldStart, 10);
    });

    test('parses binary file', () {
      const output = '''diff --git a/image.png b/image.png
Binary files a/image.png and b/image.png differ
''';
      final diffs = parseDiffOutput(output);
      expect(diffs, hasLength(1));
      expect(diffs.first.isBinary, isTrue);
      expect(diffs.first.hunks, isEmpty);
    });

    test('empty output returns empty list', () {
      expect(parseDiffOutput(''), isEmpty);
    });

    test('hunk line numbers are correct', () {
      const output = '''diff --git a/f.txt b/f.txt
index abc..def 100644
--- a/f.txt
+++ b/f.txt
@@ -5,4 +5,5 @@
 ctx
-removed
+added1
+added2
 ctx2
''';
      final diffs = parseDiffOutput(output);
      final hunk = diffs.first.hunks.first;
      expect(hunk.oldStart, 5);
      expect(hunk.newStart, 5);

      final additions = hunk.lines.where((l) => l.kind == DiffLineKind.addition).toList();
      expect(additions[0].newLineNo, 6);
      expect(additions[1].newLineNo, 7);

      final removals = hunk.lines.where((l) => l.kind == DiffLineKind.removal).toList();
      expect(removals[0].oldLineNo, 6);
    });

    test('multiple diffs in one output', () {
      const output = '''diff --git a/a.txt b/a.txt
index abc..def 100644
--- a/a.txt
+++ b/a.txt
@@ -1 +1 @@
-old
+new
diff --git a/b.txt b/b.txt
index abc..def 100644
--- a/b.txt
+++ b/b.txt
@@ -1 +1 @@
-old
+new
''';
      final diffs = parseDiffOutput(output);
      expect(diffs, hasLength(2));
      expect(diffs[0].path, 'a.txt');
      expect(diffs[1].path, 'b.txt');
    });
  });

  group('gitDiff (live)', () {
    late Directory sandbox;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('clide-git-diff-test-');
      await Process.run('git', ['init'], workingDirectory: sandbox.path);
      await Process.run(
        'git',
        ['config', 'user.email', 'test@test.com'],
        workingDirectory: sandbox.path,
      );
      await Process.run(
        'git',
        ['config', 'user.name', 'Test'],
        workingDirectory: sandbox.path,
      );
      await File('${sandbox.path}/file.txt').writeAsString('line1\nline2\n');
      await Process.run('git', ['add', '.'], workingDirectory: sandbox.path);
      await Process.run(
        'git',
        ['commit', '-m', 'init'],
        workingDirectory: sandbox.path,
      );
    });

    tearDown(() async {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('returns unstaged diff after modification', () async {
      await File('${sandbox.path}/file.txt').writeAsString('line1\nmodified\n');
      final diffs = await gitDiff(sandbox);
      expect(diffs, hasLength(1));
      expect(diffs.first.path, 'file.txt');
      expect(diffs.first.additions, greaterThan(0));
    });

    test('returns staged diff with staged: true', () async {
      await File('${sandbox.path}/file.txt').writeAsString('line1\nmodified\n');
      await Process.run(
        'git',
        ['add', 'file.txt'],
        workingDirectory: sandbox.path,
      );
      final diffs = await gitDiff(sandbox, staged: true);
      expect(diffs, hasLength(1));
    });

    test('returns empty for clean repo', () async {
      final diffs = await gitDiff(sandbox);
      expect(diffs, isEmpty);
    });
  });
}
