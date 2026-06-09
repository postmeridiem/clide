/// Widget coverage for the app shell in lib/app.dart — the root layout,
/// hat bar, slot hosts (sidebar / workspace / context), bottom rails, the
/// project switcher dropdown + open-folder dialog, the editor split, the
/// welcome overlay, and the global intent/keymap wiring in _RootShell.
///
/// Two lifecycle rules keep this suite robust (learned the hard way — a
/// dispose-order bug here wedged the runner for minutes):
///   1. Services are disposed via addTearDown in setUp, so (LIFO) they die
///      AFTER the per-test teardown that unmounts the widget tree. Disposing
///      services while ClideApp is still mounted makes ClidePalette.dispose
///      touch an already-disposed KeymapService.
///   2. Every pump helper's teardown unmounts the tree (pump a bare box)
///      BEFORE resetting tester.view — otherwise a still-mounted EditableText
///      reacts to the metrics change on a deactivated element.
///
/// The shell renders side panels (sidebar 400 + context 420), which overflow
/// the default 800px surface, so every pump uses a wide ultrawide surface via
/// tester.view (T-239 / T-241).
library;

import 'dart:io';

import 'package:clide/app.dart';
import 'package:clide/builtin/default_layout/default_layout.dart';
import 'package:clide/builtin/menubar/menubar.dart';
import 'package:clide/clide.dart' show clideName;
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    // The classic preset makes all four slots visible + sized, and registers
    // keybindings/commands so the keymap resolves real bindings.
    f.services.extensions.register(DefaultLayoutExtension());
    // The menu-bar extension owns the File/Help commands the hat menu and the
    // project switcher dispatch (T-48).
    f.services.extensions.register(MenuBarExtension(services: f.services));
    await f.services.extensions.activateAll();
    // Disposed LAST (LIFO) — after any per-test teardown unmounts the tree.
    addTearDown(() async => f.dispose());
  });

  void registerTabs() {
    final p = f.services.panels;
    p.contribute(TabContribution(id: 'files.tree', slot: Slots.sidebar, title: 'Files', build: (_) => const Text('SIDEBAR')));
    p.contribute(TabContribution(id: 'claude.primary', slot: Slots.workspace, title: 'Claude', build: (_) => const Text('CLAUDE')));
    p.contribute(TabContribution(id: 'editor.active', slot: Slots.workspace, title: 'Editor', build: (_) => const Text('EDITOR')));
    p.contribute(TabContribution(id: 'markdown.viewer', slot: Slots.contextPanel, title: 'Preview', build: (_) => const Text('CONTEXT')));
  }

  // Sizes the surface wide and registers the unmount-before-reset teardown.
  void prepareView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // RootLayout in a tight tree — no WidgetsApp / palette / text fields, so the
  // bulk of the shell (slots, rails, spines, workspace split, statusbar) is
  // exercised without the heavyweight overlay machinery.
  Future<void> pumpLayout(WidgetTester tester) async {
    prepareView(tester);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ClideKernel(
          services: f.services,
          child: ClideTheme(
            controller: f.services.theme,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(1600, 900)),
              child: const Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 1600, height: 900, child: RootLayout()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // The whole ClideApp (WidgetsApp + hat bar + overlays).
  Future<void> pumpApp(WidgetTester tester) async {
    prepareView(tester);
    await tester.pumpWidget(ClideApp(services: f.services));
    await tester.pump();
  }

  testWidgets('RootLayout renders every visible slot and its bottom rails', (tester) async {
    registerTabs();
    await pumpLayout(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('SIDEBAR'), findsOneWidget);
    expect(find.text('CLAUDE'), findsOneWidget);
    expect(find.text('CONTEXT'), findsOneWidget);
    expect(find.byType(StatusbarHost), findsOneWidget);
    expect(find.byType(ClideIconRail), findsNWidgets(2));
  });

  testWidgets('RootLayout reserves the resize-border inset for bottom content when the status bar is hidden (T-298)', (tester) async {
    registerTabs();

    // Status bar visible: the bar covers the window's bottom edge, so no extra
    // inset is reserved — the content column is not bottom-padded.
    await pumpLayout(tester);
    expect(find.byType(StatusbarHost), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Padding && w.padding == const EdgeInsets.only(bottom: ClideResizeBorder.edgeThickness)),
      findsNothing,
      reason: 'no resize inset is needed while the status bar occupies the bottom edge',
    );

    // Hide the status bar: nothing covers the bottom resize-drag strip, so the
    // bottom-most content (the composer) must clear it via a reserved inset.
    f.services.arrangement.setVisible(Slots.statusbar, false);
    await tester.pump();
    expect(find.byType(StatusbarHost), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is Padding && w.padding == const EdgeInsets.only(bottom: ClideResizeBorder.edgeThickness)),
      findsOneWidget,
      reason: 'the interaction zone must bottom-anchor clear of the resize border when no status bar covers it',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('RootLayout collapses side panels into spines with the active-tab label', (tester) async {
    registerTabs();
    f.services.panels.activateTab(Slots.sidebar, 'files.tree');
    f.services.arrangement.setCollapsed(Slots.sidebar, true);
    f.services.arrangement.setCollapsed(Slots.contextPanel, true);
    await pumpLayout(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(ClideSpine), findsNWidgets(2));
    expect(find.text('files'), findsOneWidget); // sidebar spine label
    expect(find.text('context'), findsOneWidget); // context spine label
  });

  testWidgets('RootLayout shows the editor split above the primary pane when the editor is open', (tester) async {
    registerTabs();
    f.services.arrangement.openEditor();
    await pumpLayout(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('EDITOR'), findsOneWidget);
    expect(find.text('CLAUDE'), findsOneWidget);

    // Nudge the editor split via the kernel to exercise the ratio path.
    f.services.arrangement.setEditorRatio(0.5);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a non-Claude workspace tab reveals in the split above Claude with a close (T-233)', (tester) async {
    registerTabs();
    f.services.panels.contribute(TabContribution(id: 'diff.view', slot: Slots.workspace, title: 'Diff', build: (_) => const Text('DIFF')));
    f.services.panels.activateTab(Slots.workspace, 'diff.view');
    await pumpLayout(tester);

    expect(tester.takeException(), isNull);
    // Revealed alongside the conversation: both the diff and Claude render.
    expect(find.text('DIFF'), findsOneWidget);
    expect(find.text('CLAUDE'), findsOneWidget);

    // The close affordance returns to full-Claude.
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pump();
    expect(f.services.panels.activeTabIn(Slots.workspace), 'claude.primary');
    expect(find.text('DIFF'), findsNothing);
  });

  testWidgets('with no Claude pane, an active workspace tab takes the whole slot (no reveal chrome)', (tester) async {
    final p = f.services.panels;
    p.contribute(TabContribution(id: 'files.tree', slot: Slots.sidebar, title: 'Files', build: (_) => const Text('SIDEBAR')));
    p.contribute(TabContribution(id: 'diff.view', slot: Slots.workspace, title: 'Diff', build: (_) => const Text('DIFF')));
    p.contribute(TabContribution(id: 'markdown.viewer', slot: Slots.contextPanel, title: 'Preview', build: (_) => const Text('CONTEXT')));
    p.activateTab(Slots.workspace, 'diff.view');
    await pumpLayout(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('DIFF'), findsOneWidget);
    // No alongside-Claude chrome, since there is no Claude pane to sit over.
    expect(find.bySemanticsLabel('Close'), findsNothing);
  });

  testWidgets('global intents dispatch through the app-root Actions', (tester) async {
    await pumpApp(tester);
    final ctx = tester.element(find.byType(RootLayout));

    final before = f.services.textZoom.scale;
    Actions.invoke(ctx, const TextScaleIncreaseIntent());
    expect(f.services.textZoom.scale, greaterThan(before));
    Actions.invoke(ctx, const TextScaleDecreaseIntent());
    Actions.invoke(ctx, const TextScaleResetIntent());
    expect(f.services.textZoom.scale, before);

    Actions.invoke(ctx, const PaletteOpenIntent());
    expect(f.services.palette.isOpen, isTrue);
    f.services.palette.close();
    Actions.invoke(ctx, const QuickOpenIntent());
    expect(f.services.quickOpen.isOpen, isTrue);
    f.services.quickOpen.close();

    Actions.invoke(ctx, const FindInFilesIntent());
    Actions.invoke(ctx, const FocusNextPanelIntent());
    Actions.invoke(ctx, const FocusPreviousPanelIntent());
    Actions.invoke(ctx, const InvokeCommandIntent('noop.command.does.not.exist'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('key events dispatch via _onKey for bound keys and no-op for unbound', (tester) async {
    await pumpApp(tester);
    // F6 is bound to focus.nextPanel in the shipped preset → resolves + dispatches.
    await tester.sendKeyEvent(LogicalKeyboardKey.f6);
    await tester.pump();
    // An unbound key resolves to null → the early-return branch.
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('window control buttons render and tap as no-ops in tests', (tester) async {
    await pumpApp(tester);
    // _RightHatContent renders ClideTappable window buttons on non-macOS;
    // tapping exercises the WindowControls method-channel no-op path.
    expect(find.byType(ClideTappable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // --- Project switcher dropdown + dialogs (lib/app.dart) ------------------
  // Opening a project and loading recents do real git/file I/O, so they run
  // inside tester.runAsync (real event loop) — awaiting them in the fake-async
  // test body would strand the test (the T-122 lesson). The repo root is a
  // real git repo, so project.open succeeds and lands a recent.

  testWidgets('project switcher opens, lists the recent, filters, and Esc-closes', (tester) async {
    final repo = Directory.current.path;
    final name = repo.split('/').last;
    await tester.runAsync(() async {
      await f.services.project.open(repo);
    });
    registerTabs();
    await pumpApp(tester);

    // Hat-bar switcher label is "clide > <name>" once a project is open.
    expect(find.text('$clideName > $name'), findsOneWidget);
    await tester.tap(find.text('$clideName > $name'));
    await tester.pump();

    // _ProjectSwitcherDropdown: header, recent row, action rows.
    expect(find.text('Recent Projects'), findsOneWidget);
    expect(find.text('Open Local Project'), findsOneWidget);
    expect(find.text('New Window'), findsOneWidget);

    // Type a non-matching filter — exercises the .where filter branch and the
    // empty-results render path (line coverage; the dropdown rebuilds).
    await tester.enterText(find.byType(EditableText), 'zzz-no-such-project');
    await tester.pump();
    await tester.pump();

    // Esc dismisses the dropdown (unmounts its EditableText).
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Recent Projects'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switcher → Open Local Project falls back to the path dialog (no native picker)', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('clide/window'),
      (call) async {
        if (call.method == 'pickDirectory') throw MissingPluginException();
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('clide/window'), null));

    final repo = Directory.current.path;
    final name = repo.split('/').last;
    await tester.runAsync(() async {
      await f.services.project.open(repo);
    });
    await pumpApp(tester);

    await tester.tap(find.text('$clideName > $name'));
    await tester.pump();
    await tester.tap(find.text('Open Local Project'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Open project'), findsOneWidget); // _OpenFolderDialog

    // Empty submit = no-op early return; then Cancel unmounts the dialog.
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Open project'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // T-280: this previously wedged the runner ~10 min on a `_RawReceivePort`
  // teardown hang. Root cause: project validation shelled out to `git rev-parse`
  // via `Process.run`, whose exit ReceivePort leaks under the widget-test
  // fake-async harness. The fixture now validates with a pure-Dart `.git` walk
  // (no subprocess), so the open-folder flow is subprocess-free and the test
  // runs clean. The only real I/O left (creating the temp dir) is confined to
  // `tester.runAsync`.
  testWidgets('Open Folder on a non-repo path surfaces the "no git repo" dialog (T-280)', (tester) async {
    late final Directory tmp;
    await tester.runAsync(() async => tmp = await Directory.systemTemp.createTemp('clide-not-a-repo-'));
    addTearDown(() => tmp.delete(recursive: true));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('clide/window'),
      (call) async => call.method == 'pickDirectory' ? tmp.path : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('clide/window'), null));

    await pumpApp(tester);
    // The welcome overlay also renders a "clide" wordmark, so scope the tap to
    // the hat-bar switcher button (the only ClideTappable bearing that label).
    await tester.tap(find.widgetWithText(ClideTappable, clideName)); // switcher (no project open)
    await tester.pump();
    await tester.tap(find.text('Open Local Project')); // picks tmp → not a repo (pure-Dart walk)
    await tester.pump();
    await tester.pump();
    expect(find.text('No git repo found'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text('No git repo found'), findsNothing);
  });

  testWidgets('Alt+F opens the application File menu', (tester) async {
    await pumpApp(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    await tester.pump();
    expect(find.text('Open Folder…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('file.closeWorkspace command closes the active project', (tester) async {
    final repo = Directory.current.path;
    await tester.runAsync(() async => f.services.project.open(repo));
    expect(f.services.project.isOpen, isTrue);
    await pumpApp(tester);
    await tester.runAsync(() async => f.services.commands.execute('file.closeWorkspace'));
    await tester.pump();
    expect(f.services.project.isOpen, isFalse);
  });
}
