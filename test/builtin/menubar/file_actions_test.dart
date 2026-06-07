/// Tests for FileActions + the typed-path Open dialog (T-48). The open/close
/// paths drive real `git` via project.open, so they run as plain async tests
/// (no fake-async).
library;

import 'dart:io';

import 'package:clide/builtin/menubar/src/file_actions.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    // A landing tab so openPath's activateTab has a real target.
    f.services.panels.contribute(TabContribution(id: 'claude.primary', slot: Slots.workspace, title: 'Claude', build: (_) => const SizedBox()));
  });
  tearDown(() => f.dispose());

  test('openPath opens a git repo and activates the landing tab', () async {
    final ok = await FileActions(f.services).openPath(Directory.current.path);
    expect(ok, isTrue);
    expect(f.services.project.isOpen, isTrue);
    expect(f.services.panels.activeTabIn(Slots.workspace), 'claude.primary');
  });

  test('openPath returns false for a non-repo directory', () async {
    final tmp = await Directory.systemTemp.createTemp('clide-fa-');
    addTearDown(() => tmp.delete(recursive: true));
    expect(await FileActions(f.services).openPath(tmp.path), isFalse);
  });

  test('closeWorkspace closes the active project', () async {
    final fa = FileActions(f.services);
    await fa.openPath(Directory.current.path);
    expect(f.services.project.isOpen, isTrue);
    fa.closeWorkspace();
    expect(f.services.project.isOpen, isFalse);
  });

  Widget harness(Widget child) => Directionality(
        textDirection: TextDirection.ltr,
        child: ClideKernel(
          services: f.services,
          child: ClideTheme(
            controller: f.services.theme,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: Align(alignment: Alignment.topLeft, child: child),
            ),
          ),
        ),
      );

  testWidgets('OpenFolderDialog submits the typed path via onOpen', (tester) async {
    String? opened;
    await tester.pumpWidget(harness(OpenFolderDialog(
      onOpen: (p) async => opened = p,
      onCancel: () {},
    )));
    await tester.enterText(find.byType(EditableText), '/some/repo');
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(opened, '/some/repo');
  });

  testWidgets('OpenFolderDialog surfaces an error when onOpen throws', (tester) async {
    await tester.pumpWidget(harness(OpenFolderDialog(
      onOpen: (_) async => throw StateError('not a repo'),
      onCancel: () {},
    )));
    await tester.enterText(find.byType(EditableText), '/bad');
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(find.text('Not a git repository'), findsOneWidget);
  });
}
