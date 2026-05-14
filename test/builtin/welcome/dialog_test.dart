/// Tests for the welcome view's open-project + not-a-repo dialogs.
/// Uses a custom harness that wraps the standard widget harness in a
/// DialogHost so kernel.dialog.show calls actually render their
/// builder into the tree.
library;

import 'package:clide/builtin/welcome/src/welcome_view.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

/// Wraps [harness] in a DialogHost rooted on the fixture's dialog
/// router so kernel.dialog.show(...) calls render into the tree.
Widget _harness(KernelFixture f, Widget child) {
  return harness(
    f,
    DialogHost(router: f.services.dialog, child: child),
  );
}

void main() {
  group('WelcomeView dialogs', () {
    late KernelFixture f;
    setUp(() async {
      f = await KernelFixture.create(
        i18nCatalogs: {
          'builtin.welcome': {
            const Locale('en', 'US'): const {
              'title': {'translation': 'clide'},
              'subtitle': {'translation': 'IDE'},
              'open-project': {'translation': 'Open project'},
              'open-project.hint': {'translation': 'Pick a git repository'},
              'tab.title': {'translation': 'Welcome'},
            },
          },
        },
      );
    });
    tearDown(() async => f.dispose());

    testWidgets('MissingPluginException path renders the OpenProjectDialog', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('clide/window'),
        (call) async {
          if (call.method == 'pickDirectory') {
            throw MissingPluginException();
          }
          return null;
        },
      );
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_harness(f, const WelcomeView()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open folder…'));
      await tester.pumpAndSettle();
      expect(find.text('Open project'), findsOneWidget);
      expect(find.text('Enter the path to a git repository.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('OpenProjectDialog Cancel dismisses the modal', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('clide/window'),
        (call) async => throw MissingPluginException(),
      );
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_harness(f, const WelcomeView()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open folder…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Open project'), findsNothing);
    });

    testWidgets('OpenProjectDialog Open with empty path is a no-op', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('clide/window'),
        (call) async => throw MissingPluginException(),
      );
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_harness(f, const WelcomeView()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open folder…'));
      await tester.pumpAndSettle();
      // Press Open with the text field empty.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Dialog stays.
      expect(find.text('Open project'), findsOneWidget);
    });

    testWidgets('OpenProjectDialog Open with a non-repo path keeps the dialog (project.open returns false)', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('clide/window'),
        (call) async => throw MissingPluginException(),
      );
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_harness(f, const WelcomeView()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open folder…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, '/tmp/clide-not-a-repo-${DateTime.now().microsecondsSinceEpoch}');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      // project.open returns false → dialog stays open, "Opening…" no
      // longer shows.
      expect(find.text('Open project'), findsOneWidget);
    });
  });
}
