/// Widget tests for the application menu bar (T-48): open/close, command
/// execution, disabled rendering, and keyboard navigation (arrows, Enter, Esc,
/// Left/Right between menus).
library;

import 'package:clide/builtin/menubar/menubar.dart';
import 'package:clide/clide.dart' show IpcResponse, clideVersion;
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  late MenuBarController controller;

  setUp(() async {
    f = await KernelFixture.create();
    f.services.extensions.register(MenuBarExtension(services: f.services));
    await f.services.extensions.activateAll();
    // A registered View command so the View menu has an enabled item.
    f.services.commands.register(
      CommandContribution(
        id: 'view.zoomIn',
        command: 'view.zoomIn',
        title: 'View: Zoom In',
        run: (_) async => IpcResponse.ok(id: '', data: const {}),
      ),
    );
    controller = MenuBarController();
  });

  tearDown(() async {
    controller.dispose();
    await f.dispose();
  });

  Widget harness() => Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: f.services,
      child: ClideTheme(
        controller: f.services.theme,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 900,
              height: 600,
              child: DialogHost(
                router: f.services.dialog,
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (_) => Align(
                        alignment: Alignment.topLeft,
                        child: MenuBar(controller: controller),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> openMenu(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pump(); // toggle → overlay insert
    await tester.pump(); // dropdown post-frame focus
  }

  testWidgets('renders File / View / Help buttons', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(find.text('File'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
  });

  testWidgets('opening File shows its items, incl. a disabled Close Project', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await openMenu(tester, 'File');
    expect(find.text('Open Folder…'), findsOneWidget);
    expect(find.text('New Window'), findsOneWidget);
    expect(find.text('Close Project'), findsOneWidget); // present but disabled (no project open)
  });

  testWidgets('tapping the same top button toggles the menu closed', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await openMenu(tester, 'File');
    expect(find.text('Open Folder…'), findsOneWidget);
    await tester.tap(find.text('File'));
    await tester.pump();
    expect(find.text('Open Folder…'), findsNothing);
  });

  testWidgets('Esc closes an open menu', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await openMenu(tester, 'File');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Open Folder…'), findsNothing);
  });

  testWidgets('clicking Help → About runs the command and opens the About dialog', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await openMenu(tester, 'Help');
    await tester.tap(find.text('About clide'));
    await tester.pump();
    await tester.pump();
    // The dialog renders its build-info synchronously (licenses load async).
    expect(find.text(clideVersion), findsOneWidget);
  });

  testWidgets('keyboard: Down highlights, Enter activates (Help → About)', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await openMenu(tester, 'Help');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(find.text(clideVersion), findsOneWidget);
  });

  testWidgets('keyboard: Right/Left switch between top menus', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await openMenu(tester, 'File');
    expect(find.text('Open Folder…'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight); // File → View
    await tester.pump();
    await tester.pump();
    expect(find.text('Zoom In'), findsOneWidget);
    expect(find.text('Open Folder…'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft); // View → File
    await tester.pump();
    await tester.pump();
    expect(find.text('Open Folder…'), findsOneWidget);
  });
}
