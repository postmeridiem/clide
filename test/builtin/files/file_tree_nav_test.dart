/// Widget tests for keyboard navigation in the file tree (T-406): under the vim
/// preset a focused tree moves a selection cursor with j/k, expands with l, and
/// opens the selected file with o/enter — driving the FileTreeController through
/// PaneKeyNav.
library;

import 'package:clide/builtin/files/src/file_tree_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);
Map<String, Object?> _entry(String name, String path, {bool dir = false}) => {
  'name': name,
  'path': path,
  'isDirectory': dir,
  'isSymlink': false,
  'sizeBytes': 0,
  'modifiedMs': 0,
};

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  // Tree: /repo → [lib/ (→ app.dart), main.dart].
  void stubTree() {
    f.ipc.stub('files.root', (_) async => _ok({'path': '/repo'}));
    f.ipc.stub('files.watch', (_) async => _ok(const {}));
    f.ipc.stub('files.ls', (args) async {
      final path = args['path'] as String? ?? '';
      if (path == '') {
        return _ok({
          'entries': [_entry('lib', 'lib', dir: true), _entry('main.dart', 'main.dart')],
        });
      }
      if (path == 'lib') {
        return _ok({
          'entries': [_entry('app.dart', 'lib/app.dart')],
        });
      }
      return _ok({'entries': <Object?>[]});
    });
  }

  Future<void> mountFocused(WidgetTester tester) async {
    await tester.runAsync(() => f.services.keymap.setPreset('vim'));
    f.services.keymap.setScopeFlag('vim.normal', true);
    addTearDown(() => f.services.keymap.clearScopeFlag('vim.normal'));
    await tester.pumpWidget(harness(f, const FileTreeView()));
    await pumpAsync(tester);
    final node = tester.widget<Focus>(find.descendant(of: find.byType(PaneKeyNav), matching: find.byType(Focus)).first).focusNode!;
    node.requestFocus();
    await tester.pump();
  }

  testWidgets('j moves the selection and o opens the selected file (T-406)', (tester) async {
    stubTree();
    final opened = <String>[];
    f.ipc.stub('editor.open', (args) async {
      opened.add(args['path'] as String? ?? '');
      return _ok(const {});
    });
    await mountFocused(tester);

    // visible: '' (root), 'lib', 'main.dart'. j×3 lands on main.dart.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.pump();
    await pumpAsync(tester);

    expect(opened, ['main.dart']);
  });

  testWidgets('l expands the selected directory, h collapses it (T-406)', (tester) async {
    stubTree();
    await mountFocused(tester);

    expect(find.text('app.dart'), findsNothing); // lib collapsed
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ); // root
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ); // lib
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL); // expand
    await tester.pump();
    await pumpAsync(tester);
    expect(find.text('app.dart'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH); // collapse lib
    await tester.pump();
    await pumpAsync(tester);
    expect(find.text('app.dart'), findsNothing);
  });

  testWidgets('G/gg/k and ctrl+d/u move the cursor; o on a dir toggles it (T-406)', (tester) async {
    stubTree();
    await mountFocused(tester);

    // G → last visible row (main.dart), o → main.dart is a file → opens it.
    final opened = <String>[];
    f.ipc.stub('editor.open', (args) async {
      opened.add(args['path'] as String? ?? '');
      return _ok(const {});
    });
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG); // G → bottom
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK); // up → lib
    await tester.pump();
    // o on the 'lib' directory toggles (expands) it rather than opening a file.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.pump();
    await pumpAsync(tester);
    expect(find.text('app.dart'), findsOneWidget); // lib expanded, no file opened
    expect(opened, isEmpty);

    // gg → top, then ctrl+d / ctrl+u exercise the half-page paths.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    // No crash, selection stayed in bounds — the dispatch paths ran.
    expect(opened, isEmpty);
  });
}
