/// Widget tests for PaneKeyNav (T-406): the per-pane vim-normal key handler
/// that runs its own SequenceMatcher and dispatches nav.* intents — proven
/// end-to-end against the real vim preset and scope flags.
library;

import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/kernel_fixture.dart';
import '../../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  Future<List<NavIntent>> pump(WidgetTester tester, {required Map<String, bool> scope}) async {
    // setPreset does real asset + keybindings-file I/O; run it outside the
    // fake-async zone or the testWidgets body hangs (the T-122 lesson).
    await tester.runAsync(() => f.services.keymap.setPreset('vim'));
    for (final e in scope.entries) {
      f.services.keymap.setScopeFlag(e.key, e.value);
    }
    final got = <NavIntent>[];
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      harness(f, PaneKeyNav(focusNode: node, autofocus: true, onNav: (i, _) => got.add(i), child: const SizedBox(width: 100, height: 100))),
    );
    node.requestFocus();
    await tester.pump();
    return got;
  }

  testWidgets('bare motions dispatch nav.* under vim.normal (pane focused)', (tester) async {
    final got = await pump(tester, scope: {'vim.normal': true});
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    expect(got, [isA<NavDownIntent>(), isA<NavUpIntent>(), isA<NavCollapseOrLeftIntent>(), isA<NavExpandOrRightIntent>()]);
  });

  testWidgets('gg sequence resolves to nav.top', (tester) async {
    final got = await pump(tester, scope: {'vim.normal': true});
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    expect(got, [isA<NavTopIntent>()]);
  });

  testWidgets('ctrl+d / ctrl+u are claimed as half-page nav', (tester) async {
    final got = await pump(tester, scope: {'vim.normal': true});
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(got, [isA<NavPageDownIntent>(), isA<NavPageUpIntent>()]);
  });

  testWidgets('the editor.focused guard suppresses nav (keys go to the editor)', (tester) async {
    final got = await pump(tester, scope: {'vim.normal': true, 'editor.focused': true});
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    // j/k now resolve to editor.vim.* — not NavIntents — so onNav never fires.
    expect(got, isEmpty);
  });

  testWidgets('keys pass through outside vim normal mode', (tester) async {
    final got = await pump(tester, scope: {'vim.insert': true});
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    expect(got, isEmpty);
  });

  testWidgets('an unbound bare key is swallowed without dispatching nav', (tester) async {
    final got = await pump(tester, scope: {'vim.normal': true});
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    expect(got, isEmpty);
  });
}
