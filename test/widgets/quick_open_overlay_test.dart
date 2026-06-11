/// Widget tests for [QuickOpenOverlay] — loads the file list via the
/// stubbed `files.walk`, routes a selection through [openWorkspaceFile]
/// (.md → markdown reader bus, else editor.open), and records recents
/// (T-51).
library;

import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    f.ipc.stub(
      'files.walk',
      (_) async => IpcResponse.ok(
        id: '1',
        data: const {
          'files': ['lib/main.dart', 'lib/app.dart', 'README.md'],
          'truncated': false,
        },
      ),
    );
    f.ipc.stub('editor.open', (args) async => IpcResponse.ok(id: '1', data: {'path': args['path']}));
  });
  tearDown(() => f.dispose());

  testWidgets('hidden until opened, then loads files and filters', (tester) async {
    await tester.pumpWidget(harness(f, const QuickOpenOverlay()));
    expect(find.byType(EditableText), findsNothing);

    f.services.quickOpen.open();
    await pumpAsync(tester);
    // File list loaded from files.walk.
    expect(f.services.quickOpen.truncated, isFalse);

    await tester.enterText(find.byType(EditableText), 'app');
    await pumpAsync(tester);
    expect(find.text('app.dart'), findsOneWidget);
    expect(find.text('main.dart'), findsNothing);
  });

  testWidgets('tapping a non-md result opens the editor and records a recent', (tester) async {
    String? opened;
    f.ipc.stub('editor.open', (args) async {
      opened = args['path'] as String?;
      return IpcResponse.ok(id: '1', data: {'path': args['path']});
    });
    await tester.pumpWidget(harness(f, const QuickOpenOverlay()));
    f.services.quickOpen.open();
    await pumpAsync(tester);
    await tester.enterText(find.byType(EditableText), 'main');
    await pumpAsync(tester);

    await tester.tap(find.text('main.dart'));
    await pumpAsync(tester);

    expect(opened, 'lib/main.dart');
    expect(f.services.quickOpen.isOpen, isFalse);
    expect(f.services.recentFiles.paths, contains('lib/main.dart'));
  });

  testWidgets('tapping an md result publishes to the markdown reader bus', (tester) async {
    final published = <Message>[];
    final sub = f.services.messages.subscribe(publisher: 'builtin.markdown', channel: 'selection').listen(published.add);
    addTearDown(sub.cancel);

    await tester.pumpWidget(harness(f, const QuickOpenOverlay()));
    f.services.quickOpen.open();
    await pumpAsync(tester);
    await tester.enterText(find.byType(EditableText), 'readme');
    await pumpAsync(tester);

    await tester.tap(find.text('README.md'));
    await pumpAsync(tester);

    expect(published, hasLength(1));
    expect(published.first.data['path'], 'README.md');
    expect(f.services.recentFiles.paths, contains('README.md'));
  });

  testWidgets('empty query shows recents once any file has been opened', (tester) async {
    f.services.recentFiles.push('lib/app.dart');
    await tester.pumpWidget(harness(f, const QuickOpenOverlay()));
    f.services.quickOpen.open();
    await pumpAsync(tester);
    // Empty query → recents listed.
    expect(find.text('app.dart'), findsOneWidget);
  });

  testWidgets('a non-matching query shows the no-match hint', (tester) async {
    await tester.pumpWidget(harness(f, const QuickOpenOverlay()));
    f.services.quickOpen.open();
    await pumpAsync(tester);
    await tester.enterText(find.byType(EditableText), 'zzzzz-nope');
    await pumpAsync(tester);
    expect(find.text('No matching files'), findsOneWidget);
  });

  testWidgets('truncated walk surfaces the limited-results hint', (tester) async {
    f.ipc.stub(
      'files.walk',
      (_) async => IpcResponse.ok(
        id: '1',
        data: const {
          'files': ['lib/main.dart'],
          'truncated': true,
        },
      ),
    );
    await tester.pumpWidget(harness(f, const QuickOpenOverlay()));
    f.services.quickOpen.open();
    await pumpAsync(tester);
    await tester.enterText(find.byType(EditableText), 'main');
    await pumpAsync(tester);
    expect(find.text('Results limited — large workspace'), findsOneWidget);
  });

  testWidgets('keymap intents drive nav, accept and dismiss', (tester) async {
    String? opened;
    f.ipc.stub('editor.open', (args) async {
      opened = args['path'] as String?;
      return IpcResponse.ok(id: '1', data: {'path': args['path']});
    });
    await tester.pumpWidget(harness(f, const QuickOpenOverlay()));
    f.services.quickOpen.open();
    await pumpAsync(tester);
    await tester.enterText(find.byType(EditableText), 'lib');
    await pumpAsync(tester);

    final ctx = tester.element(find.byType(EditableText));
    Actions.invoke(ctx, const QuickOpenSelectNextIntent());
    await pumpAsync(tester);
    Actions.invoke(ctx, const QuickOpenSelectPreviousIntent());
    await pumpAsync(tester);
    // Accept opens the highlighted result in the editor.
    Actions.invoke(ctx, const QuickOpenAcceptIntent());
    await pumpAsync(tester);
    expect(opened, isNotNull);
    expect(f.services.quickOpen.isOpen, isFalse);
  });

  testWidgets('dismiss intent closes the overlay', (tester) async {
    await tester.pumpWidget(harness(f, const QuickOpenOverlay()));
    f.services.quickOpen.open();
    await pumpAsync(tester);
    final ctx = tester.element(find.byType(EditableText));
    Actions.invoke(ctx, const DismissIntent());
    await pumpAsync(tester);
    expect(f.services.quickOpen.isOpen, isFalse);
  });

  testWidgets('files.walk failure leaves the list empty (no crash)', (tester) async {
    f.ipc.stub(
      'files.walk',
      (_) async => IpcResponse.err(
        id: '1',
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'boom'),
      ),
    );
    await tester.pumpWidget(harness(f, const QuickOpenOverlay()));
    f.services.quickOpen.open();
    await pumpAsync(tester);
    await tester.enterText(find.byType(EditableText), 'main');
    await pumpAsync(tester);
    expect(find.text('No matching files'), findsOneWidget);
  });

  testWidgets('the palette is width-capped (not stretched) on an ultrawide surface (T-241)', (tester) async {
    setSurfaceSize(tester, 3440);
    await tester.pumpWidget(harness(f, const QuickOpenOverlay()));
    f.services.quickOpen.open();
    await pumpAsync(tester);
    // The panel is a fixed 480 — the filter field must stay capped, not span the
    // full 3440 (a Row/Expanded regression would stretch it edge to edge).
    final field = tester.getRect(find.byType(EditableText));
    expect(field.width, lessThan(600), reason: 'capped to the panel, not stretched across the ultrawide surface');
  });
}
