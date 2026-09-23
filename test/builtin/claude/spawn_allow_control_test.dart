/// The agent spawn allowlist settings control (D-115): lists the entries,
/// adds and removes them, and stores them at the app-scope key the pane
/// commands read.
///
/// Settings writes are real file I/O, so they run in [WidgetTester.runAsync].
library;

import 'package:clide/builtin/claude/src/spawn_allow_control.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    harness(
      f,
      const Align(
        alignment: Alignment.center,
        child: SizedBox(width: 420, child: SpawnAllowControl()),
      ),
    ),
  );

  test('the allowlist lives in app scope', () {
    // `app.*` keys are read only from the app layer (settings.dart), so a
    // repo's settings can never supply or extend the list.
    expect(kSpawnAllowKey, startsWith('app.'));
  });

  testWidgets('empty: says every command asks first', (tester) async {
    await pump(tester);
    expect(find.textContaining('every command an agent starts asks'), findsOneWidget);
  });

  Future<void> add(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(ClideEditable), text);
    await tester.runAsync(() async {
      await tester.tap(find.text('Add command'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }

  testWidgets('adds normalised entries; ignores blanks, a bare * and duplicates', (tester) async {
    await pump(tester);
    await add(tester, '  make   test ');
    await add(tester, 'flutter test *');
    await add(tester, '*');
    await add(tester, '   ');
    await add(tester, 'make test');
    expect(readSpawnAllow(f.services.settings), ['make test', 'flutter test *']);
    expect(find.text('make test'), findsOneWidget);
    expect(find.text('flutter test *'), findsOneWidget);
  });

  testWidgets('removes an entry', (tester) async {
    await tester.runAsync(() => f.services.settings.set<List<String>>(kSpawnAllowKey, ['make test', 'make analyze']));
    await pump(tester);
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.bySemanticsLabel('Remove make test'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(readSpawnAllow(f.services.settings), ['make analyze']);
  });

  test('readSpawnAllow ignores non-string entries', () async {
    await f.services.settings.set<List<Object>>(kSpawnAllowKey, ['make test', 3, true]);
    expect(readSpawnAllow(f.services.settings), ['make test']);
  });
}
