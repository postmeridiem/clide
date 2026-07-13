/// D-106/T-511: the per-workspace PATH preset settings control. Covers the
/// no-workspace and empty states, add/remove/reorder against the real
/// settings store, worktree key sharing, live updates on a CLI-side write,
/// and the capture-from-login-shell suggestion flow.
///
/// Settings writes are real file I/O, so seeding goes through
/// [WidgetTester.runAsync] — awaiting it inside the fake-async body would hang.
library;

import 'dart:io';

import 'package:clide/builtin/tools_settings/src/path_preset_control.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/env_path_commands.dart' show envPathChannel;
import 'package:clide/src/env/path_preset.dart';
import 'package:clide/src/env/shell_env.dart' show debugResetLoginShellPath, debugSetLoginShellPath;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  List<String> dirs(String root) => presetDirsFrom((k) => f.services.settings.get<Object>(k), root);

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    harness(
      f,
      const Align(
        alignment: Alignment.center,
        child: SizedBox(width: 460, child: PathPresetControl()),
      ),
    ),
  );

  testWidgets('no workspace open → prompts to open one', (tester) async {
    await pump(tester);
    await tester.pump();
    expect(find.textContaining('Open a workspace'), findsOneWidget);
  });

  testWidgets('empty preset shows the hint + the add row', (tester) async {
    await tester.runAsync(() => f.services.settings.setProjectDir(f.tempDir));
    await pump(tester);
    await tester.pump();
    expect(find.textContaining('No preset entries'), findsOneWidget);
    expect(find.text('Add entry'), findsOneWidget);
  });

  testWidgets('typing a dir + Add persists it, publishes on envPathChannel, and renders the row', (tester) async {
    await tester.runAsync(() => f.services.settings.setProjectDir(f.tempDir));
    final published = <Map<String, Object?>>[];
    final sub = f.services.messages.subscribe(channel: envPathChannel).listen((m) => published.add(m.data));
    addTearDown(sub.cancel);

    await pump(tester);
    await tester.pump();
    await tester.enterText(find.byType(EditableText), '/opt/go/bin');
    await tester.tap(find.text('Add entry'));
    await tester.pump();

    expect(dirs(f.tempDir.path), ['/opt/go/bin']);
    expect(find.text('/opt/go/bin'), findsOneWidget);
    expect(find.text('missing'), findsOneWidget, reason: 'the dir does not exist → warning tag');
    expect(published.single['action'], 'add');
    expect(published.single['dirs'], ['/opt/go/bin']);
  });

  testWidgets('a relative entry is rejected with a visible reason and nothing is written', (tester) async {
    await tester.runAsync(() => f.services.settings.setProjectDir(f.tempDir));
    await pump(tester);
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'go/bin');
    await tester.tap(find.text('Add entry'));
    await tester.pump();
    expect(find.textContaining('absolute path'), findsOneWidget);
    expect(dirs(f.tempDir.path), isEmpty);
  });

  testWidgets('an existing dir renders without the missing tag', (tester) async {
    await tester.runAsync(() async {
      await f.services.settings.setProjectDir(f.tempDir);
      await f.services.settings.setAt(SettingsScope.app, pathPresetKey(f.tempDir.path), [f.tempDir.path]);
    });
    await pump(tester);
    await tester.pump();
    expect(find.text(f.tempDir.path), findsOneWidget);
    expect(find.text('missing'), findsNothing);
  });

  testWidgets('remove and reorder rewrite the stored order', (tester) async {
    await tester.runAsync(() async {
      await f.services.settings.setProjectDir(f.tempDir);
      await f.services.settings.setAt(SettingsScope.app, pathPresetKey(f.tempDir.path), ['/a', '/b', '/c']);
    });
    await pump(tester);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Move down: /a'));
    await tester.pump();
    expect(dirs(f.tempDir.path), ['/b', '/a', '/c']);

    await tester.tap(find.bySemanticsLabel('Move up: /c'));
    await tester.pump();
    expect(dirs(f.tempDir.path), ['/b', '/c', '/a']);

    await tester.tap(find.bySemanticsLabel('Remove: /b'));
    await tester.pump();
    expect(dirs(f.tempDir.path), ['/c', '/a']);
  });

  testWidgets('live-updates when the preset changes from outside (CLI-side write)', (tester) async {
    await tester.runAsync(() => f.services.settings.setProjectDir(f.tempDir));
    await pump(tester);
    await tester.pump();
    expect(find.textContaining('No preset entries'), findsOneWidget);

    await tester.runAsync(() => f.services.settings.setAt(SettingsScope.app, pathPresetKey(f.tempDir.path), ['/from/cli']));
    await tester.pump();
    expect(find.text('/from/cli'), findsOneWidget);
  });

  testWidgets('opened from an in-repo worktree: says so and edits the main repo key (D-106)', (tester) async {
    late Directory repo;
    late Directory wt;
    await tester.runAsync(() async {
      repo = Directory('${f.tempDir.path}/repo')..createSync();
      Directory('${repo.path}/.git/worktrees/fix').createSync(recursive: true);
      wt = Directory('${repo.path}/.worktrees/fix')..createSync(recursive: true);
      File('${wt.path}/.git').writeAsStringSync('gitdir: ${repo.path}/.git/worktrees/fix\n');
      await f.services.settings.setProjectDir(wt);
    });

    await pump(tester);
    await tester.pump();
    expect(find.textContaining('Worktree'), findsOneWidget);
    expect(find.text(repo.path), findsOneWidget, reason: 'names the shared main repo root');

    await tester.enterText(find.byType(EditableText), '/opt/go/bin');
    await tester.tap(find.text('Add entry'));
    await tester.pump();
    expect(dirs(repo.path), ['/opt/go/bin'], reason: 'worktree writes land on the main repo key');
    expect(dirs(wt.path), ['/opt/go/bin'], reason: 'reading via the worktree resolves the same key');
  });

  testWidgets('capture suggests login-shell dirs and a tap adopts one', (tester) async {
    debugSetLoginShellPath('/cap-a:${Platform.environment['PATH'] ?? ''}');
    addTearDown(debugResetLoginShellPath);
    await tester.runAsync(() => f.services.settings.setProjectDir(f.tempDir));

    await pump(tester);
    await tester.pump();
    await tester.tap(find.text('Suggest from login shell'));
    await tester.pump();
    expect(find.text('/cap-a'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Add suggested entry: /cap-a'));
    await tester.pump();
    expect(dirs(f.tempDir.path), ['/cap-a']);
    expect(find.bySemanticsLabel('Add suggested entry: /cap-a'), findsNothing, reason: 'adopted suggestion leaves the list');
  });

  testWidgets('capture with no login-shell probe reports nothing to suggest', (tester) async {
    debugResetLoginShellPath();
    addTearDown(debugResetLoginShellPath);
    await tester.runAsync(() => f.services.settings.setProjectDir(f.tempDir));
    await pump(tester);
    await tester.pump();
    await tester.tap(find.text('Suggest from login shell'));
    await tester.pump();
    expect(find.textContaining('Nothing to suggest'), findsOneWidget);
  });
}
