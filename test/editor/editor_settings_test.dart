import 'package:clide/src/editor/editor_settings.dart';
import 'package:test/test.dart';

void main() {
  group('EditorSettings model', () {
    test('toJson omits unset keys; fromJson round-trips', () {
      expect(const EditorSettings().toJson(), isEmpty);
      const s = EditorSettings(indentStyle: 'space', indentSize: 2, maxLineLength: 80, insertFinalNewline: true);
      expect(EditorSettings.fromJson(s.toJson()).toJson(), s.toJson());
      expect(EditorSettings.fromJson('not a map'), EditorSettings.empty);
    });

    test('isEmpty + eolString', () {
      expect(EditorSettings.empty.isEmpty, isTrue);
      expect(const EditorSettings(indentSize: 2).isEmpty, isFalse);
      expect(const EditorSettings(endOfLine: 'crlf').eolString, '\r\n');
      expect(const EditorSettings(endOfLine: 'lf').eolString, '\n');
      expect(const EditorSettings(endOfLine: 'cr').eolString, '\r');
      expect(EditorSettings.empty.eolString, isNull);
    });

    test('indentUnit reflects style + size', () {
      expect(const EditorSettings(indentStyle: 'tab').indentUnit, '\t');
      expect(const EditorSettings(indentStyle: 'space', indentSize: 3).indentUnit, '   ');
      expect(const EditorSettings(indentStyle: 'space').indentUnit, '    '); // defaults to 4
      expect(const EditorSettings(indentSize: 2).indentUnit, '  '); // size with no style → spaces
      expect(EditorSettings.empty.indentUnit, isNull); // no opinion → keep default
    });

    test('merge — later source wins per set field, others fall through', () {
      const base = EditorSettings(indentStyle: 'space', indentSize: 2, maxLineLength: 80);
      const over = EditorSettings(indentSize: 4, insertFinalNewline: true);
      final m = base.merge(over);
      expect(m.indentSize, 4); // overridden
      expect(m.indentStyle, 'space'); // inherited
      expect(m.maxLineLength, 80); // inherited
      expect(m.insertFinalNewline, isTrue); // added
      // Merging empty over a value is a no-op; value over empty adopts it.
      expect(base.merge(EditorSettings.empty).toJson(), base.toJson());
      expect(EditorSettings.empty.merge(base).toJson(), base.toJson());
    });
  });

  group('EditorSettings.applyOnSave', () {
    test('trims trailing whitespace on every line, any EOL', () {
      const cfg = EditorSettings(trimTrailingWhitespace: true);
      expect(cfg.applyOnSave('a   \nb\t\nc'), 'a\nb\nc');
      expect(cfg.applyOnSave('a  \r\nb \r\n'), 'a\r\nb\r\n');
    });

    test('inserts a final newline when missing', () {
      const cfg = EditorSettings(insertFinalNewline: true);
      expect(cfg.applyOnSave('abc'), 'abc\n');
      expect(cfg.applyOnSave('abc\n'), 'abc\n');
    });

    test('insert_final_newline=false strips trailing newlines', () {
      expect(const EditorSettings(insertFinalNewline: false).applyOnSave('abc\n\n'), 'abc');
    });

    test('final newline uses the configured EOL, else the detected one', () {
      expect(const EditorSettings(endOfLine: 'crlf', insertFinalNewline: true).applyOnSave('abc'), 'abc\r\n');
      expect(const EditorSettings(insertFinalNewline: true).applyOnSave('a\r\nb'), 'a\r\nb\r\n');
    });

    test('normalizes EOL across the whole file', () {
      expect(const EditorSettings(endOfLine: 'crlf').applyOnSave('a\nb\nc'), 'a\r\nb\r\nc');
      expect(const EditorSettings(endOfLine: 'lf').applyOnSave('a\r\nb\r\n'), 'a\nb\n');
    });

    test('no opinion (and empty content) leaves the text untouched', () {
      expect(EditorSettings.empty.applyOnSave('a  \r\nb'), 'a  \r\nb');
      expect(const EditorSettings(insertFinalNewline: true).applyOnSave(''), '');
    });

    test('composes trim + EOL + final newline in order', () {
      const cfg = EditorSettings(trimTrailingWhitespace: true, endOfLine: 'lf', insertFinalNewline: true);
      expect(cfg.applyOnSave('a  \r\nb\t'), 'a\nb\n');
    });
  });
}
