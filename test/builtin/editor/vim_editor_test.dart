/// T-206: the editor's modal wiring. With a `vim.normal` scope flag set
/// and a sequence binding registered, a bare key drives the buffer (and
/// the editor goes read-only so the key can't also type); under no Vim
/// mode the editor types normally.
library;

import 'package:clide/builtin/editor/src/editor_view.dart';
import 'package:clide/clide.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  void stubOneBuffer(String content) {
    f.ipc.stub(
        'editor.list',
        (_) async => _ok({
              'buffers': [
                {'id': 'b_1', 'path': 'lib/a.dart', 'dirty': false}
              ]
            }));
    f.ipc.stub(
        'editor.active',
        (_) async => _ok({
              'active': {'id': 'b_1'}
            }));
    f.ipc.stub(
        'editor.read',
        (_) async => _ok({
              'id': 'b_1',
              'path': 'lib/a.dart',
              'content': content,
              'selection': {'start': 0, 'end': 0},
              'dirty': false,
            }));
  }

  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(harness(f, const EditorView()));
    await tester.pumpAndSettle();
    // Tap the very start so the caret lands at offset 0 (a centred tap
    // would put it at end-of-text and make column-sensitive ops no-ops).
    await tester.tapAt(tester.getTopLeft(find.byType(EditableText)) + const Offset(1, 1));
    await tester.pump();
  }

  testWidgets('normal-mode x deletes the char under the caret', (tester) async {
    String? sentText;
    f.ipc.stub('editor.set-content', (a) async {
      sentText = a['text'] as String?;
      return _ok(const {});
    });
    f.services.keymap.registerCommandBinding('x', 'editor.vim.deleteChar', when: 'vim.normal');
    f.services.keymap.setScopeFlag('vim.normal', true);

    stubOneBuffer('hello');
    await pumpEditor(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.pumpAndSettle();

    expect(sentText, 'ello');
  });

  testWidgets('dd sequence deletes the line', (tester) async {
    String? sentText;
    f.ipc.stub('editor.set-content', (a) async {
      sentText = a['text'] as String?;
      return _ok(const {});
    });
    f.services.keymap.registerCommandBinding('d d', 'editor.vim.deleteLine', when: 'vim.normal');
    f.services.keymap.setScopeFlag('vim.normal', true);

    stubOneBuffer('one\ntwo');
    await pumpEditor(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();

    expect(sentText, 'two');
  });

  testWidgets('the editor is read-only in normal mode, writable otherwise', (tester) async {
    f.services.keymap.setScopeFlag('vim.normal', true);
    stubOneBuffer('hello');
    await pumpEditor(tester);

    expect(tester.widget<EditableText>(find.byType(EditableText)).readOnly, isTrue);

    f.services.keymap.setScopeFlag('vim.normal', false);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(find.byType(EditableText)).readOnly, isFalse);
  });

  testWidgets('an unbound bare key in normal mode is swallowed (no edit)', (tester) async {
    String? lastText;
    f.ipc.stub('editor.set-content', (a) async {
      lastText = a['text'] as String?;
      return _ok(const {});
    });
    f.services.keymap.setScopeFlag('vim.normal', true);
    stubOneBuffer('hello');
    await pumpEditor(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.pumpAndSettle();

    // The buffer text is never altered by an unbound normal-mode key.
    expect(lastText, anyOf(isNull, 'hello'));
  });
}
