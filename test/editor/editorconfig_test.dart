import 'dart:io';

import 'package:clide/src/editor/editorconfig.dart';
import 'package:test/test.dart';

void main() {
  group('editorSettingsFromProps', () {
    test('maps the common indent + newline keys', () {
      final c = editorSettingsFromProps({
        'indent_style': 'space',
        'indent_size': '2',
        'end_of_line': 'lf',
        'trim_trailing_whitespace': 'true',
        'insert_final_newline': 'true',
        'max_line_length': '100',
      });
      expect(c.indentStyle, 'space');
      expect(c.indentSize, 2);
      expect(c.tabWidth, 2); // defaults to indent_size
      expect(c.endOfLine, 'lf');
      expect(c.trimTrailingWhitespace, isTrue);
      expect(c.insertFinalNewline, isTrue);
      expect(c.maxLineLength, 100);
    });

    test('indent_size = tab follows tab_width', () {
      final c = editorSettingsFromProps({'indent_style': 'tab', 'indent_size': 'tab', 'tab_width': '4'});
      expect(c.indentSize, 4);
      expect(c.tabWidth, 4);
    });

    test('tab indent with no indent_size defaults to tab_width', () {
      expect(editorSettingsFromProps({'indent_style': 'tab', 'tab_width': '8'}).indentSize, 8);
    });

    test('max_line_length = off and unset values resolve to null', () {
      final c = editorSettingsFromProps({'max_line_length': 'off', 'indent_style': 'unset', 'insert_final_newline': 'unset'});
      expect(c.maxLineLength, isNull);
      expect(c.indentStyle, isNull);
      expect(c.insertFinalNewline, isNull);
    });

    test('rejects junk values rather than guessing', () {
      final c = editorSettingsFromProps({'indent_style': 'tabs', 'indent_size': '-3', 'end_of_line': 'mac'});
      expect(c.indentStyle, isNull);
      expect(c.indentSize, isNull);
      expect(c.endOfLine, isNull);
    });
  });

  group('readEditorConfig — glob matching', () {
    late Directory root;
    setUp(() async => root = await Directory.systemTemp.createTemp('clide-ec-glob-'));
    tearDown(() => root.deleteSync(recursive: true));

    Future<void> write(String relPath, String contents) async {
      final f = File('${root.path}/$relPath');
      await f.parent.create(recursive: true);
      await f.writeAsString(contents);
    }

    test('[*] applies to every file', () async {
      await write('.editorconfig', 'root = true\n[*]\nindent_size = 2\n');
      expect(readEditorConfig(root, 'a.txt').indentSize, 2);
      expect(readEditorConfig(root, 'sub/b.dart').indentSize, 2);
    });

    test('extension globs and brace alternation', () async {
      await write('.editorconfig', 'root = true\n[*.dart]\nindent_size = 2\n[*.{js,ts}]\nindent_size = 4\n');
      expect(readEditorConfig(root, 'main.dart').indentSize, 2);
      expect(readEditorConfig(root, 'app.js').indentSize, 4);
      expect(readEditorConfig(root, 'app.ts').indentSize, 4);
      expect(readEditorConfig(root, 'readme.md').indentSize, isNull);
    });

    test('a slash anchors the glob to the config dir; ** spans dirs', () async {
      await write('.editorconfig', 'root = true\n[lib/**.dart]\nindent_size = 3\n');
      expect(readEditorConfig(root, 'lib/a.dart').indentSize, 3);
      expect(readEditorConfig(root, 'lib/deep/b.dart').indentSize, 3);
      expect(readEditorConfig(root, 'test/c.dart').indentSize, isNull);
    });

    test('? matches exactly one non-separator char', () async {
      await write('.editorconfig', 'root = true\n[?.txt]\nindent_size = 9\n');
      expect(readEditorConfig(root, 'a.txt').indentSize, 9);
      expect(readEditorConfig(root, 'ab.txt').indentSize, isNull);
    });

    test('leading **/ matches in the config dir and below', () async {
      await write('.editorconfig', 'root = true\n[**/foo.txt]\nindent_size = 3\n');
      expect(readEditorConfig(root, 'foo.txt').indentSize, 3);
      expect(readEditorConfig(root, 'a/b/foo.txt').indentSize, 3);
    });

    test('negated character class', () async {
      await write('.editorconfig', 'root = true\n[[!a-c].txt]\nindent_size = 4\n');
      expect(readEditorConfig(root, 'z.txt').indentSize, 4);
      expect(readEditorConfig(root, 'b.txt').indentSize, isNull);
    });

    test('numeric range', () async {
      await write('.editorconfig', 'root = true\n[file{1..3}.txt]\nindent_size = 7\n');
      expect(readEditorConfig(root, 'file2.txt').indentSize, 7);
      expect(readEditorConfig(root, 'file9.txt').indentSize, isNull);
    });

    test('an oversized numeric range falls back to a generic integer match', () async {
      await write('.editorconfig', 'root = true\n[v{1..5000}]\nindent_size = 6\n');
      expect(readEditorConfig(root, 'v123').indentSize, 6);
      expect(readEditorConfig(root, 'vx').indentSize, isNull);
    });

    test('a brace with no top-level comma and an unterminated class are literal', () async {
      await write('.editorconfig', 'root = true\n[a{b}.txt]\nindent_size = 2\n[lit[.md]\nindent_size = 8\n');
      expect(readEditorConfig(root, 'a{b}.txt').indentSize, 2);
      expect(readEditorConfig(root, 'lit[.md').indentSize, 8);
    });

    test('backslash escapes a glob metacharacter to a literal', () async {
      await write('.editorconfig', 'root = true\n[a\\{b.txt]\nindent_size = 5\n');
      expect(readEditorConfig(root, 'a{b.txt').indentSize, 5);
      expect(readEditorConfig(root, 'aXb.txt').indentSize, isNull);
    });

    test('an unterminated brace (even with an escaped }) is literal', () async {
      await write('.editorconfig', 'root = true\n[x{a\\}b.txt]\nindent_size = 6\n');
      expect(readEditorConfig(root, 'x{a}b.txt').indentSize, 6);
    });

    test('escaped chars inside a class and inside an alternation', () async {
      await write('.editorconfig', 'root = true\n[[a\\-c].txt]\nindent_size = 3\n[{a\\,b,c}.md]\nindent_size = 4\n');
      expect(readEditorConfig(root, 'c.txt').indentSize, 3);
      expect(readEditorConfig(root, 'c.md').indentSize, 4);
    });
  });

  group('readEditorConfig — precedence', () {
    late Directory root;
    setUp(() async => root = await Directory.systemTemp.createTemp('clide-ec-prec-'));
    tearDown(() => root.deleteSync(recursive: true));

    Future<void> write(String relPath, String contents) async {
      final f = File('${root.path}/$relPath');
      await f.parent.create(recursive: true);
      await f.writeAsString(contents);
    }

    test('a nearer config overrides a farther one', () async {
      await write('.editorconfig', 'root = true\n[*]\nindent_size = 2\nindent_style = space\n');
      await write('sub/.editorconfig', '[*]\nindent_size = 4\n');
      final c = readEditorConfig(root, 'sub/x.dart');
      expect(c.indentSize, 4);
      expect(c.indentStyle, 'space');
    });

    test('root = true halts the ascent', () async {
      await write('.editorconfig', '[*]\nindent_style = tab\n');
      await write('sub/.editorconfig', 'root = true\n[*]\nindent_size = 4\n');
      final c = readEditorConfig(root, 'sub/x.dart');
      expect(c.indentSize, 4);
      expect(c.indentStyle, isNull);
    });

    test('later sections in one file win', () async {
      await write('.editorconfig', 'root = true\n[*]\nindent_size = 2\n[*.dart]\nindent_size = 4\n');
      expect(readEditorConfig(root, 'a.dart').indentSize, 4);
    });

    test('a nearer "unset" clears an inherited property', () async {
      await write('.editorconfig', 'root = true\n[*]\nindent_style = space\n');
      await write('sub/.editorconfig', '[*]\nindent_style = unset\n');
      expect(readEditorConfig(root, 'sub/x.txt').indentStyle, isNull);
    });

    test('no .editorconfig anywhere resolves to empty', () async {
      expect(readEditorConfig(root, 'a.txt').isEmpty, isTrue);
    });

    test('a malformed file is skipped, not fatal', () async {
      await write('.editorconfig', 'root = true\n[*\nindent_size = 2\nnonsense line\n[*]\nindent_size = 8\n');
      expect(readEditorConfig(root, 'a.txt').indentSize, 8);
    });

    test('comments (# and ;) are ignored', () async {
      await write('.editorconfig', '# top comment\nroot = true\n[*]\n; inline note\nindent_size = 2\n');
      expect(readEditorConfig(root, 'a.txt').indentSize, 2);
    });
  });
}
