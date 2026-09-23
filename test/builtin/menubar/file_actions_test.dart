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

import '../../helpers/git_sandbox.dart';
import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart' show OverlayHost;

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    // A landing tab so openPath's activateTab has a real target.
    f.services.panels.contribute(TabContribution(id: 'claude.primary', slot: Slots.workspace, title: 'Claude', build: (_) => const SizedBox()));
  });
  tearDown(() => f.dispose());

  // A throwaway repo, never the clide checkout itself: opening a project
  // can write into it (T-639).
  Future<Directory> repo() async {
    final dir = await newSandboxRepo(prefix: 'clide-fa-repo-', files: const {'README.md': '# fixture\n'});
    addTearDown(() => dir.delete(recursive: true));
    return dir;
  }

  test('openPath opens a git repo and activates the landing tab', () async {
    final ok = await FileActions(f.services).openPath((await repo()).path);
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
    await fa.openPath((await repo()).path);
    expect(f.services.project.isOpen, isTrue);
    fa.closeWorkspace();
    expect(f.services.project.isOpen, isFalse);
  });

  group('newWindowEnvironment (T-421)', () {
    test("strips this window's IPC identity and keeps everything else", () {
      final env = FileActions.newWindowEnvironment(const {
        'CLIDE_SOCK': '/run/user/1000/clide-abc.sock',
        'CLIDE_WORKSPACE': '/home/me/repo-a',
        'PATH': '/usr/bin',
        'HOME': '/home/me',
        'CLIDE_TIMEOUT_MS': '750',
      });
      expect(env, {'PATH': '/usr/bin', 'HOME': '/home/me', 'CLIDE_TIMEOUT_MS': '750'});
    });

    test('matches the identity keys case-insensitively (Windows env names)', () {
      expect(FileActions.newWindowEnvironment(const {'clide_sock': 'x', 'Clide_Workspace': 'y', 'Path': 'z'}), {'Path': 'z'});
    });

    test('an environment without the keys passes through unchanged', () {
      expect(FileActions.newWindowEnvironment(const {'PATH': '/usr/bin'}), {'PATH': '/usr/bin'});
    });
  });

  Widget harness(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: f.services,
      child: ClideTheme(
        controller: f.services.theme,
        child: MediaQuery(
          data: const MediaQueryData(),
          // The dialog's path field needs an Overlay ancestor for its
          // context menu, as it has in the app under WidgetsApp.
          child: Align(
            alignment: Alignment.topLeft,
            child: OverlayHost(child: child),
          ),
        ),
      ),
    ),
  );

  testWidgets('OpenFolderDialog submits the typed path via onOpen', (tester) async {
    String? opened;
    await tester.pumpWidget(harness(OpenFolderDialog(onOpen: (p) async => opened = p, onCancel: () {})));
    await tester.enterText(find.byType(EditableText), '/some/repo');
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(opened, '/some/repo');
  });

  testWidgets('OpenFolderDialog surfaces an error when onOpen throws', (tester) async {
    await tester.pumpWidget(harness(OpenFolderDialog(onOpen: (_) async => throw StateError('not a repo'), onCancel: () {})));
    await tester.enterText(find.byType(EditableText), '/bad');
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(find.text('Not a git repository'), findsOneWidget);
  });
}
