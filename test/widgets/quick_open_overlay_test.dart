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
        (_) async => IpcResponse.ok(id: '1', data: const {
              'files': ['lib/main.dart', 'lib/app.dart', 'README.md'],
              'truncated': false,
            }));
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
}
