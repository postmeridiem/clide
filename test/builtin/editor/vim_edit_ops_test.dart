/// T-206: the pure Vim motion/edit engine. Drives [applyVim] over
/// `(text, caret)` and asserts the resulting text, caret, register, and
/// insert-mode request.
library;

import 'package:clide/builtin/editor/src/vim_edit_ops.dart';
import 'package:flutter/services.dart' show TextEditingValue, TextSelection;
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _tev(String text, int caret, {int? anchor}) => TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: anchor ?? caret, extentOffset: caret),
    );

void main() {
  group('motions', () {
    const t = 'hello\nworld\nfoo';

    test('right / left stop at line bounds', () {
      expect(applyVim(VimAction.right, _tev(t, 0)).value.selection.extentOffset, 1);
      expect(applyVim(VimAction.left, _tev(t, 1)).value.selection.extentOffset, 0);
      expect(applyVim(VimAction.left, _tev(t, 0)).value.selection.extentOffset, 0);
    });

    test('down / up preserve column', () {
      expect(applyVim(VimAction.down, _tev(t, 2)).value.selection.extentOffset, 8); // world, col 2
      expect(applyVim(VimAction.up, _tev(t, 8)).value.selection.extentOffset, 2);
    });

    test('down on the last line stays put', () {
      expect(applyVim(VimAction.down, _tev(t, 13)).value.selection.extentOffset, 13);
    });

    test('lineStart / lineEnd / firstNonBlank', () {
      expect(applyVim(VimAction.lineEnd, _tev(t, 0)).value.selection.extentOffset, 5);
      expect(applyVim(VimAction.lineStart, _tev(t, 8)).value.selection.extentOffset, 6);
      expect(applyVim(VimAction.firstNonBlank, _tev('  ab', 3)).value.selection.extentOffset, 2);
    });

    test('word motions', () {
      const w = 'hello world';
      expect(applyVim(VimAction.wordForward, _tev(w, 0)).value.selection.extentOffset, 6);
      expect(applyVim(VimAction.wordBackward, _tev(w, 8)).value.selection.extentOffset, 6);
      expect(applyVim(VimAction.wordEnd, _tev(w, 0)).value.selection.extentOffset, 4);
    });

    test('docStart / docEnd', () {
      expect(applyVim(VimAction.docStart, _tev(t, 8)).value.selection.extentOffset, 0);
      expect(applyVim(VimAction.docEnd, _tev(t, 0)).value.selection.extentOffset, 12);
    });

    test('count repeats a motion (3·right)', () {
      expect(applyVim(VimAction.right, _tev(t, 0), count: 3).value.selection.extentOffset, 3);
    });

    test('visual motion extends from the anchor', () {
      final r = applyVim(VimAction.right, _tev(t, 0, anchor: 0), visual: true, count: 3);
      expect(r.value.selection.baseOffset, 0);
      expect(r.value.selection.extentOffset, 3);
    });
  });

  group('edits', () {
    test('x deletes the char under the caret', () {
      final r = applyVim(VimAction.deleteChar, _tev('hello', 0));
      expect(r.value.text, 'ello');
      expect(r.value.selection.extentOffset, 0);
      expect(r.register?.text, 'h');
    });

    test('x with a count', () {
      expect(applyVim(VimAction.deleteChar, _tev('hello', 0), count: 2).value.text, 'llo');
    });

    test('dd deletes the line linewise', () {
      final r = applyVim(VimAction.deleteLine, _tev('hello\nworld\nfoo', 0));
      expect(r.value.text, 'world\nfoo');
      expect(r.value.selection.extentOffset, 0);
      expect(r.register?.text, 'hello\n');
      expect(r.register?.linewise, isTrue);
    });

    test('dd on the last line drops the preceding newline', () {
      final r = applyVim(VimAction.deleteLine, _tev('a\nb', 2));
      expect(r.value.text, 'a');
      expect(r.value.selection.extentOffset, 0);
    });

    test('2dd deletes two lines', () {
      final r = applyVim(VimAction.deleteLine, _tev('a\nb\nc', 0), count: 2);
      expect(r.value.text, 'c');
    });

    test('D deletes to end of line', () {
      final r = applyVim(VimAction.deleteToEnd, _tev('hello', 2));
      expect(r.value.text, 'he');
      expect(r.register?.text, 'llo');
    });

    test('dw deletes to the next word', () {
      final r = applyVim(VimAction.deleteWord, _tev('hello world', 0));
      expect(r.value.text, 'world');
      expect(r.value.selection.extentOffset, 0);
    });

    test('yy yanks linewise without changing text', () {
      final r = applyVim(VimAction.yankLine, _tev('hello\nworld', 0));
      expect(r.value.text, 'hello\nworld');
      expect(r.register?.text, 'hello\n');
      expect(r.register?.linewise, isTrue);
    });

    test('p pastes a linewise register below', () {
      final r = applyVim(VimAction.paste, _tev('a\nb', 0), register: const VimRegister('x\n', linewise: true));
      expect(r.value.text, 'a\nx\nb');
      expect(r.value.selection.extentOffset, 2);
    });

    test('P pastes a linewise register above', () {
      final r = applyVim(VimAction.pasteBefore, _tev('a\nb', 0), register: const VimRegister('x\n', linewise: true));
      expect(r.value.text, 'x\na\nb');
      expect(r.value.selection.extentOffset, 0);
    });

    test('p pastes a charwise register after the caret', () {
      final r = applyVim(VimAction.paste, _tev('ac', 0), register: const VimRegister('b'));
      expect(r.value.text, 'abc');
      expect(r.value.selection.extentOffset, 1);
    });

    test('o opens a line below and enters insert', () {
      final r = applyVim(VimAction.openBelow, _tev('a\nb', 0));
      expect(r.value.text, 'a\n\nb');
      expect(r.value.selection.extentOffset, 2);
      expect(r.enterInsert, isTrue);
    });

    test('O opens a line above and enters insert', () {
      final r = applyVim(VimAction.openAbove, _tev('a', 0));
      expect(r.value.text, '\na');
      expect(r.value.selection.extentOffset, 0);
      expect(r.enterInsert, isTrue);
    });

    test('cc clears the line and enters insert', () {
      final r = applyVim(VimAction.changeLine, _tev('hello\nworld', 0));
      expect(r.value.text, '\nworld');
      expect(r.value.selection.extentOffset, 0);
      expect(r.enterInsert, isTrue);
      expect(r.register?.linewise, isTrue);
    });
  });

  group('insert entry', () {
    test('i stays, a advances, A goes to line end, I to first non-blank', () {
      expect(applyVim(VimAction.insert, _tev('ab', 0)).enterInsert, isTrue);
      expect(applyVim(VimAction.insert, _tev('ab', 0)).value.selection.extentOffset, 0);
      expect(applyVim(VimAction.append, _tev('ab', 0)).value.selection.extentOffset, 1);
      expect(applyVim(VimAction.appendLineEnd, _tev('ab', 0)).value.selection.extentOffset, 2);
      expect(applyVim(VimAction.insertLineStart, _tev('  ab', 0)).value.selection.extentOffset, 2);
    });
  });

  group('visual range ops', () {
    test('visual delete removes the inclusive range', () {
      final r = applyVim(VimAction.visualDelete, _tev('hello', 2, anchor: 0), visual: true);
      expect(r.value.text, 'lo');
      expect(r.value.selection.extentOffset, 0);
      expect(r.register?.text, 'hel');
    });

    test('visual yank keeps text and stores the range', () {
      final r = applyVim(VimAction.visualYank, _tev('hello', 2, anchor: 0), visual: true);
      expect(r.value.text, 'hello');
      expect(r.register?.text, 'hel');
    });

    test('visual change deletes and enters insert', () {
      final r = applyVim(VimAction.visualChange, _tev('hello', 2, anchor: 0), visual: true);
      expect(r.value.text, 'lo');
      expect(r.enterInsert, isTrue);
    });
  });

  test('unknown action is a no-op', () {
    final v = _tev('abc', 1);
    final r = applyVim('editor.vim.nope', v);
    expect(r.value, v);
  });
}
