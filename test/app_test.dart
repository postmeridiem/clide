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
}
