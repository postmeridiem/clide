/// Widget tests for the Vim ex command-line overlay (T-407): each v1 command
/// row dispatches the right editor IPC verb (or seeds quick-open), unknown
/// commands keep the overlay open with a hint, and Esc dismisses it.
///
/// Built on a tight, sized Stack rather than the shared `harness()` — the
/// overlay is a `Positioned` child and needs a bounded Stack ancestor (the
/// canSizeOverlay harness mis-sizes positioned content).
library;

import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

IpcResponse _ok([Map<String, Object?> data = const {}]) => IpcResponse.ok(id: '', data: data);

void main() {
  late KernelFixture f;

  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  Widget mount() => Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: f.services,
      child: ClideTheme(
        controller: f.services.theme,
        child: const MediaQuery(
          data: MediaQueryData(size: Size(800, 600)),
          child: SizedBox(width: 800, height: 600, child: Stack(children: [ExLineOverlay()])),
        ),
      ),
    ),
  );

  /// Open the overlay and type [text] into it (no submit yet).
  Future<void> openAndType(WidgetTester tester, String text) async {
    await tester.pumpWidget(mount());
    f.services.exLine.open();
    await pumpAsync(tester);
    await tester.enterText(find.byType(EditableText), text);
    await pumpAsync(tester);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpAsync(tester);
  }

  testWidgets('closed: renders nothing', (tester) async {
    await tester.pumpWidget(mount());
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets(':w saves the active buffer and closes', (tester) async {
    var saved = false;
    f.ipc.stub('editor.save', (_) async {
      saved = true;
      return _ok();
    });
    await openAndType(tester, 'w');
    await submit(tester);
    expect(saved, isTrue);
    expect(f.services.exLine.isOpen, isFalse);
  });

  testWidgets(':q closes the active tab via its id', (tester) async {
    String? closed;
    f.ipc.stub(
      'editor.active',
      (_) async => _ok({
        'active': {'id': 'b_9'},
      }),
    );
    f.ipc.stub('editor.close', (a) async {
      closed = a['id'] as String?;
      return _ok();
    });
    await openAndType(tester, 'q');
    await submit(tester);
    expect(closed, 'b_9');
    expect(f.services.exLine.isOpen, isFalse);
  });

  testWidgets(':42 dispatches editor.goto-line', (tester) async {
    Object? line;
    f.ipc.stub('editor.goto-line', (a) async {
      line = a['line'];
      return _ok();
    });
    await openAndType(tester, '42');
    await submit(tester);
    expect(line, 42);
  });

  testWidgets(':e seeds quick-open and closes the ex-line', (tester) async {
    await openAndType(tester, 'e lib/main.dart');
    await submit(tester);
    expect(f.services.exLine.isOpen, isFalse);
    expect(f.services.quickOpen.isOpen, isTrue);
    expect(f.services.quickOpen.filter, 'lib/main.dart');
  });

  testWidgets('unknown command keeps the overlay open and shows the hint', (tester) async {
    await openAndType(tester, 'nope');
    await submit(tester);
    expect(f.services.exLine.isOpen, isTrue);
    expect(find.text('Not an editor command'), findsOneWidget);
  });

  testWidgets('editing after a rejection clears the hint', (tester) async {
    await openAndType(tester, 'nope');
    await submit(tester);
    expect(find.text('Not an editor command'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'w');
    await pumpAsync(tester);
    expect(find.text('Not an editor command'), findsNothing);
  });

  testWidgets('DismissIntent closes the overlay', (tester) async {
    await openAndType(tester, 'w');
    final ctx = tester.element(find.byType(EditableText));
    Actions.invoke(ctx, const DismissIntent());
    await pumpAsync(tester);
    expect(f.services.exLine.isOpen, isFalse);
  });

  testWidgets('opening publishes the exline.open scope flag; closing clears it', (tester) async {
    await tester.pumpWidget(mount());
    f.services.exLine.open();
    await pumpAsync(tester);
    expect(f.services.keymap.scope['exline.open'], isTrue);
    f.services.exLine.close();
    await pumpAsync(tester);
    expect(f.services.keymap.scope['exline.open'], isNot(true));
  });
}
