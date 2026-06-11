/// Widget tests for the multi-tab editor view: a tab per open buffer
/// (filename + dirty marker), the empty-state hint, and tab taps
/// routing to `editor.activate`. Buffer-list logic itself is covered
/// in editor_controller_test.dart.
library;

import 'package:clide/builtin/editor/src/editor_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

Finder _closeIcons() => find.byWidgetPredicate((w) => w is ClideIcon && w.painter is CloseIcon);

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);

Map<String, Object?> _buf(String id, String path, {bool dirty = false}) => {'id': id, 'path': path, 'dirty': dirty};

Map<String, Object?> _read(String id, String path, {Map<String, Object?>? settings}) => {
  'id': id,
  'path': path,
  'content': 'content of $path',
  'selection': {'start': 0, 'end': 0},
  'dirty': false,
  'editorSettings': ?settings,
};

Finder _ruler() => find.byWidgetPredicate((w) => w is CustomPaint && w.painter?.runtimeType.toString() == '_RulerPainter');

void main() {
  group('EditorView tabs', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    void stubBuffers(List<Map<String, Object?>> buffers, {String? active}) {
      f.ipc.stub('editor.list', (_) async => _ok({'buffers': buffers}));
      f.ipc.stub(
        'editor.active',
        (_) async => active == null
            ? _ok(const {})
            : _ok({
                'active': {'id': active},
              }),
      );
      f.ipc.stub('editor.read', (a) async {
        final id = a['id'] as String;
        final b = buffers.firstWhere((b) => b['id'] == id);
        return _ok(_read(id, b['path'] as String));
      });
    }

    testWidgets('renders one tab per open buffer, by filename', (tester) async {
      stubBuffers([_buf('b_1', 'lib/a.dart'), _buf('b_2', 'src/b.dart')], active: 'b_1');
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();
      expect(find.text('a.dart'), findsOneWidget);
      expect(find.text('b.dart'), findsOneWidget);
    });

    testWidgets('a dirty buffer carries a marker in its tab title', (tester) async {
      stubBuffers([_buf('b_1', 'lib/a.dart', dirty: true)], active: 'b_1');
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();
      expect(find.text('a.dart •'), findsOneWidget);
    });

    testWidgets('no open buffers shows the open-a-file hint', (tester) async {
      stubBuffers(const [], active: null);
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();
      expect(find.text('Open a file to begin editing.'), findsOneWidget);
    });

    testWidgets('tapping an inactive tab routes to editor.activate', (tester) async {
      stubBuffers([_buf('b_1', 'lib/a.dart'), _buf('b_2', 'src/b.dart')], active: 'b_1');
      String? activated;
      f.ipc.stub('editor.activate', (a) async {
        activated = a['id'] as String?;
        return _ok({'active': a['id']});
      });
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('b.dart'));
      await tester.pumpAndSettle();

      expect(activated, 'b_2');
    });

    testWidgets('closing a tab routes to editor.close', (tester) async {
      stubBuffers([_buf('b_1', 'lib/a.dart')], active: 'b_1');
      String? closed;
      f.ipc.stub('editor.close', (a) async {
        closed = a['id'] as String?;
        return _ok(const {});
      });
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();

      expect(_closeIcons(), findsWidgets);
      await tester.tap(_closeIcons().first);
      await tester.pumpAndSettle();

      expect(closed, 'b_1');
    });

    testWidgets('typing in the editor mirrors to editor.set-content', (tester) async {
      stubBuffers([_buf('b_1', 'lib/a.dart')], active: 'b_1');
      Map<String, Object?>? setArgs;
      f.ipc.stub('editor.set-content', (a) async {
        setArgs = a;
        return _ok(const {});
      });
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText), 'edited body');
      await tester.pumpAndSettle();

      expect(setArgs?['id'], 'b_1');
      expect(setArgs?['text'], 'edited body');
    });

    testWidgets('Ctrl+S in the editor triggers editor.save', (tester) async {
      stubBuffers([_buf('b_1', 'lib/a.dart')], active: 'b_1');
      String? saved;
      f.ipc.stub('editor.save', (a) async {
        saved = a['id'] as String?;
        return _ok(const {});
      });
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(saved, 'b_1');
    });

    void stubOne(String path, {Map<String, Object?>? settings}) {
      f.ipc.stub(
        'editor.list',
        (_) async => _ok({
          'buffers': [_buf('b_1', path)],
        }),
      );
      f.ipc.stub(
        'editor.active',
        (_) async => _ok({
          'active': {'id': 'b_1'},
        }),
      );
      f.ipc.stub('editor.read', (_) async => _ok(_read('b_1', path, settings: settings)));
    }

    testWidgets('Tab indents per the resolved settings (spaces)', (tester) async {
      stubOne('lib/a.dart', settings: {'indent_style': 'space', 'indent_size': 2});
      f.ipc.stub('editor.set-content', (_) async => _ok(const {}));
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();

      final before = tester.widget<EditableText>(find.byType(EditableText)).controller.text;
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final after = tester.widget<EditableText>(find.byType(EditableText)).controller.text;
      expect(after.length, before.length + 2); // two spaces inserted
      expect(after, contains('  ')); // adjacent pair our indent added
    });

    void stubReadContent(String path, String content, Map<String, Object?> settings) {
      f.ipc.stub(
        'editor.list',
        (_) async => _ok({
          'buffers': [_buf('b_1', path)],
        }),
      );
      f.ipc.stub(
        'editor.active',
        (_) async => _ok({
          'active': {'id': 'b_1'},
        }),
      );
      f.ipc.stub(
        'editor.read',
        (_) async => _ok({
          'id': 'b_1',
          'path': path,
          'content': content,
          'selection': {'start': 0, 'end': 0},
          'dirty': false,
          'editorSettings': settings,
        }),
      );
      f.ipc.stub('editor.set-content', (_) async => _ok(const {}));
    }

    testWidgets('Shift+Tab dedents a space-indented line', (tester) async {
      stubReadContent('lib/a.dart', '    x', {'indent_style': 'space', 'indent_size': 2});
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '  x'); // two spaces stripped
    });

    testWidgets('Shift+Tab dedents one leading tab', (tester) async {
      stubReadContent('lib/a.dart', '\t\tx', {'indent_style': 'tab', 'tab_width': 4});
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '\tx'); // one tab stripped
    });

    testWidgets('a max_line_length renders the wrap-guide ruler', (tester) async {
      stubOne('lib/a.dart', settings: {'max_line_length': 80});
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();
      expect(_ruler(), findsOneWidget);
    });

    testWidgets('no max_line_length draws no ruler', (tester) async {
      stubOne('lib/a.dart');
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();
      expect(_ruler(), findsNothing);
    });
  });
}
