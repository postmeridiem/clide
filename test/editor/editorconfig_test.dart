import 'dart:io';

import 'package:clide/src/editor/editorconfig.dart';
import 'package:test/test.dart';

void main() {
  group('EditorConfig.fromProps', () {
    test('parses the common indent + newline keys', () {
      final c = EditorConfig.fromProps({
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
      final c = EditorConfig.fromProps({'indent_style': 'tab', 'indent_size': 'tab', 'tab_width': '4'});
      expect(c.indentSize, 4);
      expect(c.tabWidth, 4);
    });

    test('tab indent with no indent_size defaults to tab_width', () {
      final c = EditorConfig.fromProps({'indent_style': 'tab', 'tab_width': '8'});
      expect(c.indentSize, 8);
    });

    test('max_line_length = off and unset values resolve to null', () {
      final c = EditorConfig.fromProps({'max_line_length': 'off', 'indent_style': 'unset', 'insert_final_newline': 'unset'});
      expect(c.maxLineLength, isNull);
      expect(c.indentStyle, isNull);
      expect(c.insertFinalNewline, isNull);
    });

    test('rejects junk values rather than guessing', () {
      final c = EditorConfig.fromProps({'indent_style': 'tabs', 'indent_size': '-3', 'end_of_line': 'mac'});
      expect(c.indentStyle, isNull);
      expect(c.indentSize, isNull);
      expect(c.endOfLine, isNull);
    });

    test('toJson omits unset keys', () {
      expect(const EditorConfig().toJson(), isEmpty);
      expect(const EditorConfig(indentStyle: 'space', indentSize: 2).toJson(), {'indent_style': 'space', 'indent_size': 2});
    });
  });

  group('applyEditorConfigOnSave', () {
    test('trims trailing whitespace on every line, any EOL', () {
      const cfg = EditorConfig(trimTrailingWhitespace: true);
      expect(applyEditorConfigOnSave('a   \nb\t\nc', cfg), 'a\nb\nc');
      expect(applyEditorConfigOnSave('a  \r\nb \r\n', cfg), 'a\r\nb\r\n');
    });

    test('inserts a final newline when missing', () {
      const cfg = EditorConfig(insertFinalNewline: true);
      expect(applyEditorConfigOnSave('abc', cfg), 'abc\n');
      expect(applyEditorConfigOnSave('abc\n', cfg), 'abc\n'); // already present
    });

    test('insert_final_newline=false strips trailing newlines', () {
      const cfg = EditorConfig(insertFinalNewline: false);
      expect(applyEditorConfigOnSave('abc\n\n', cfg), 'abc');
    });

    test('final newline uses the configured EOL', () {
      const cfg = EditorConfig(endOfLine: 'crlf', insertFinalNewline: true);
      expect(applyEditorConfigOnSave('abc', cfg), 'abc\r\n');
    });

    test('normalizes EOL across the whole file', () {
      const cfg = EditorConfig(endOfLine: 'crlf');
      expect(applyEditorConfigOnSave('a\nb\nc', cfg), 'a\r\nb\r\nc');
      const lf = EditorConfig(endOfLine: 'lf');
      expect(applyEditorConfigOnSave('a\r\nb\r\n', lf), 'a\nb\n');
    });

    test('no opinion leaves the content untouched', () {
      expect(applyEditorConfigOnSave('a  \r\nb', EditorConfig.empty), 'a  \r\nb');
      expect(applyEditorConfigOnSave('', const EditorConfig(insertFinalNewline: true)), '');
    });

    test('with no EOL set, the inserted final newline matches the file style', () {
      const cfg = EditorConfig(insertFinalNewline: true);
      expect(applyEditorConfigOnSave('a\r\nb', cfg), 'a\r\nb\r\n'); // detected crlf
    });

    test('composes trim + EOL + final newline in order', () {
      const cfg = EditorConfig(trimTrailingWhitespace: true, endOfLine: 'lf', insertFinalNewline: true);
      expect(applyEditorConfigOnSave('a  \r\nb\t', cfg), 'a\nb\n');
    });
  });

  group('resolveEditorConfig — glob matching', () {
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
      expect(resolveEditorConfig(root, 'a.txt').indentSize, 2);
      expect(resolveEditorConfig(root, 'sub/b.dart').indentSize, 2);
    });

    test('extension globs and brace alternation', () async {
      await write('.editorconfig', 'root = true\n[*.dart]\nindent_size = 2\n[*.{js,ts}]\nindent_size = 4\n');
      expect(resolveEditorConfig(root, 'main.dart').indentSize, 2);
      expect(resolveEditorConfig(root, 'app.js').indentSize, 4);
      expect(resolveEditorConfig(root, 'app.ts').indentSize, 4);
      expect(resolveEditorConfig(root, 'readme.md').indentSize, isNull);
    });

    test('a slash anchors the glob to the config dir; ** spans dirs', () async {
      await write('.editorconfig', 'root = true\n[lib/**.dart]\nindent_size = 3\n');
      expect(resolveEditorConfig(root, 'lib/a.dart').indentSize, 3);
      expect(resolveEditorConfig(root, 'lib/deep/b.dart').indentSize, 3);
      expect(resolveEditorConfig(root, 'test/c.dart').indentSize, isNull);
    });

    test('character class and negation', () async {
      await write('.editorconfig', 'root = true\n[[a-c].txt]\nindent_size = 5\n[!x].md]\nindent_size = 6\n');
      expect(resolveEditorConfig(root, 'b.txt').indentSize, 5);
      expect(resolveEditorConfig(root, 'z.txt').indentSize, isNull);
    });

    test('numeric range', () async {
      await write('.editorconfig', 'root = true\n[file{1..3}.txt]\nindent_size = 7\n');
      expect(resolveEditorConfig(root, 'file2.txt').indentSize, 7);
      expect(resolveEditorConfig(root, 'file9.txt').indentSize, isNull);
    });

    test('? matches exactly one non-separator char', () async {
      await write('.editorconfig', 'root = true\n[?.txt]\nindent_size = 9\n');
      expect(resolveEditorConfig(root, 'a.txt').indentSize, 9);
      expect(resolveEditorConfig(root, 'ab.txt').indentSize, isNull);
    });

    test('leading **/ matches in the config dir and below', () async {
      await write('.editorconfig', 'root = true\n[**/foo.txt]\nindent_size = 3\n');
      expect(resolveEditorConfig(root, 'foo.txt').indentSize, 3);
      expect(resolveEditorConfig(root, 'a/b/foo.txt').indentSize, 3);
    });

    test('negated character class', () async {
      await write('.editorconfig', 'root = true\n[[!a-c].txt]\nindent_size = 4\n');
      expect(resolveEditorConfig(root, 'z.txt').indentSize, 4);
      expect(resolveEditorConfig(root, 'b.txt').indentSize, isNull);
    });

    test('an oversized numeric range falls back to a generic integer match', () async {
      await write('.editorconfig', 'root = true\n[v{1..5000}]\nindent_size = 6\n');
      expect(resolveEditorConfig(root, 'v123').indentSize, 6);
      expect(resolveEditorConfig(root, 'vx').indentSize, isNull);
    });

    test('a brace with no top-level comma and an unterminated class are literal', () async {
      await write('.editorconfig', 'root = true\n[a{b}.txt]\nindent_size = 2\n[lit[.md]\nindent_size = 8\n');
      // {b} is a literal brace group → matches the literal text "a{b}.txt".
      expect(resolveEditorConfig(root, 'a{b}.txt').indentSize, 2);
      // "[lit[.md" has an unterminated class → the leading [ is literal.
      expect(resolveEditorConfig(root, 'lit[.md').indentSize, 8);
    });

    test('backslash escapes a glob metacharacter to a literal', () async {
      await write('.editorconfig', 'root = true\n[a\\{b.txt]\nindent_size = 5\n');
      expect(resolveEditorConfig(root, 'a{b.txt').indentSize, 5);
      expect(resolveEditorConfig(root, 'aXb.txt').indentSize, isNull);
    });

    test('an unterminated brace (even with an escaped }) is literal', () async {
      await write('.editorconfig', 'root = true\n[x{a\\}b.txt]\nindent_size = 6\n');
      expect(resolveEditorConfig(root, 'x{a}b.txt').indentSize, 6);
    });

    test('escaped chars inside a class and inside an alternation', () async {
      await write('.editorconfig', 'root = true\n[[a\\-c].txt]\nindent_size = 3\n[{a\\,b,c}.md]\nindent_size = 4\n');
      expect(resolveEditorConfig(root, 'c.txt').indentSize, 3); // c is in the class
      expect(resolveEditorConfig(root, 'c.md').indentSize, 4); // 'c' alternative
    });
  });

  group('resolveEditorConfig — precedence', () {
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
      final c = resolveEditorConfig(root, 'sub/x.dart');
      expect(c.indentSize, 4); // overridden by nearer
      expect(c.indentStyle, 'space'); // inherited from farther
    });

    test('root = true halts the ascent', () async {
      await write('.editorconfig', '[*]\nindent_style = tab\n'); // would apply if reached
      await write('sub/.editorconfig', 'root = true\n[*]\nindent_size = 4\n');
      final c = resolveEditorConfig(root, 'sub/x.dart');
      expect(c.indentSize, 4);
      expect(c.indentStyle, isNull); // top-level file never consulted
    });

    test('later sections in one file win', () async {
      await write('.editorconfig', 'root = true\n[*]\nindent_size = 2\n[*.dart]\nindent_size = 4\n');
      expect(resolveEditorConfig(root, 'a.dart').indentSize, 4);
    });

    test('a nearer "unset" clears an inherited property', () async {
      await write('.editorconfig', 'root = true\n[*]\nindent_style = space\n');
      await write('sub/.editorconfig', '[*]\nindent_style = unset\n');
      expect(resolveEditorConfig(root, 'sub/x.txt').indentStyle, isNull);
    });

    test('no .editorconfig anywhere resolves to empty', () async {
      expect(resolveEditorConfig(root, 'a.txt').isEmpty, isTrue);
    });

    test('a malformed file is skipped, not fatal', () async {
      await write('.editorconfig', 'root = true\n[*\nindent_size = 2\nnonsense line\n[*]\nindent_size = 8\n');
      // The broken section header is ignored; the valid [*] still applies.
      expect(resolveEditorConfig(root, 'a.txt').indentSize, 8);
    });

    test('comments (# and ;) are ignored', () async {
      await write('.editorconfig', '# top comment\nroot = true\n[*]\n; inline note\nindent_size = 2\n');
      expect(resolveEditorConfig(root, 'a.txt').indentSize, 2);
    });
  });
}
