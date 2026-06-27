/// T-482: the per-workspace Claude account picker settings control. Covers the
/// no-workspace and no-accounts empty states, and the bind flow — the dropdown
/// lists Default + registered accounts, and picking one binds the workspace and
/// publishes the `set` action on accountActionChannel (driving respawn + lock
/// sync, T-480/T-479).
///
/// Registry/settings writes are real file I/O, so seeding goes through
/// [WidgetTester.runAsync] — awaiting it inside the fake-async body would hang.
library;

import 'package:clide/builtin/claude/src/account_registry.dart';
import 'package:clide/builtin/claude/src/account_settings_control.dart';
import 'package:clide/src/daemon/claude_account_commands.dart' show accountActionChannel;
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
        child: SizedBox(width: 320, child: ClaudeWorkspaceAccountControl()),
      ),
    ),
  );

  testWidgets('no workspace open → prompts to open one', (tester) async {
    await pump(tester);
    await tester.pump();
    expect(find.textContaining('Open a workspace'), findsOneWidget);
  });

  testWidgets('workspace open but no accounts → hints at the CLI verb', (tester) async {
    await tester.runAsync(() => f.services.settings.setProjectDir(f.tempDir));
    await pump(tester);
    await tester.pump();
    expect(find.textContaining('No accounts yet'), findsOneWidget);
  });

  testWidgets('lists Default + accounts; picking one binds the workspace and publishes set', (tester) async {
    final reg = AccountRegistry(f.services.settings);
    await tester.runAsync(() async {
      await f.services.settings.setProjectDir(f.tempDir);
      await reg.registerAccount('work', '/home/u/.claude-work');
      await reg.registerAccount('personal', '/home/u/.claude-personal');
    });

    final published = <Map<String, Object?>>[];
    final sub = f.services.messages.subscribe(channel: accountActionChannel).listen((m) => published.add(m.data));
    addTearDown(sub.cancel);

    await pump(tester);
    await tester.pump();
    expect(find.textContaining('Default'), findsOneWidget, reason: 'anchor shows Default while unbound');

    await tester.tap(find.byType(ClaudeWorkspaceAccountControl));
    await tester.pump();
    expect(find.text('work'), findsOneWidget);
    expect(find.text('personal'), findsOneWidget);

    await tester.tap(find.text('work'));
    await tester.pump();
    expect(reg.boundName(f.tempDir.path), 'work');
    expect(published.single['action'], 'set');
    expect(published.single['name'], 'work');
  });

  testWidgets('picking Default while bound unbinds the workspace and publishes unset', (tester) async {
    final reg = AccountRegistry(f.services.settings);
    await tester.runAsync(() async {
      await f.services.settings.setProjectDir(f.tempDir);
      await reg.registerAccount('work', '/home/u/.claude-work');
      await reg.bindWorkspace(f.tempDir.path, 'work');
    });

    final published = <Map<String, Object?>>[];
    final sub = f.services.messages.subscribe(channel: accountActionChannel).listen((m) => published.add(m.data));
    addTearDown(sub.cancel);

    await pump(tester);
    await tester.pump();
    await tester.tap(find.byType(ClaudeWorkspaceAccountControl));
    await tester.pump();
    await tester.tap(find.textContaining('Default'));
    await tester.pump();
    expect(reg.boundName(f.tempDir.path), isNull);
    expect(published.single['action'], 'unset');
    expect(published.single['previous'], 'work');
  });

  // The global registry list control (T-482 part 2).
  Future<void> pumpList(WidgetTester tester) => tester.pumpWidget(
    harness(
      f,
      const Align(
        alignment: Alignment.center,
        child: SizedBox(width: 460, child: ClaudeAccountsListControl()),
      ),
    ),
  );

  testWidgets('registry list: empty shows a hint + the add row', (tester) async {
    await pumpList(tester);
    await tester.pump();
    expect(find.textContaining('No accounts registered'), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
  });

  testWidgets('registry list: renders each account name + dir', (tester) async {
    final reg = AccountRegistry(f.services.settings);
    await tester.runAsync(() => reg.registerAccount('work', '/home/u/.claude-work'));
    await pumpList(tester);
    await tester.pump();
    expect(find.text('work'), findsOneWidget);
    expect(find.text('/home/u/.claude-work'), findsOneWidget);
  });

  testWidgets('registry list: typing a name + Add registers it and publishes login', (tester) async {
    final reg = AccountRegistry(f.services.settings);
    final published = <Map<String, Object?>>[];
    final sub = f.services.messages.subscribe(channel: accountActionChannel).listen((m) => published.add(m.data));
    addTearDown(sub.cancel);

    await pumpList(tester);
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'work');
    await tester.tap(find.text('Add account'));
    await tester.pump();
    expect(reg.accountByName('work'), isNotNull);
    expect(published.single['action'], 'login');
    expect(published.single['name'], 'work');
  });

  testWidgets('registry list: remove deletes an unbound account; a bound one is guarded', (tester) async {
    final reg = AccountRegistry(f.services.settings);
    await tester.runAsync(() async {
      await f.services.settings.setProjectDir(f.tempDir);
      await reg.registerAccount('work', '/home/u/.claude-work');
      await reg.registerAccount('personal', '/home/u/.claude-personal');
      await reg.bindWorkspace(f.tempDir.path, 'work');
    });

    await pumpList(tester);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Remove personal'));
    await tester.pump();
    expect(reg.accountByName('personal'), isNull);
    expect(find.bySemanticsLabel(RegExp('bound to a workspace')), findsOneWidget, reason: 'the bound account guards its remove');
  });
}
