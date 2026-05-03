import 'dart:ui';

import 'package:clide/builtin/theme_picker/theme_picker.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

ThemeDefinition _def(String name) => ThemeDefinition(
      name: name,
      displayName: name,
      dark: true,
      palette: Palette(const {
        'primary': Color(0xFF00A3D2),
        'accent': Color(0xFFFA5F8B),
        'background': Color(0xFF21262F),
        'surface': Color(0xFF393E48),
        'panel': Color(0xFF292E38),
        'foreground': Color(0xFFE2E8F5),
        'success': Color(0xFF00AB9A),
        'warning': Color(0xFFD08447),
        'error': Color(0xFFF06C6F),
      }),
    );

void main() {
  group('ThemePickerExtension', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create(
        bundledThemes: [_def('summer-night'), _def('forest')],
        i18nCatalogs: {
          'builtin.theme-picker': {
            const Locale('en', 'US'): const {
              'modal.title': {'translation': 'Select theme'},
              'modal.cancel': {'translation': 'Cancel'},
              'modal.cancel.hint': {'translation': 'Dismiss'},
              'row.select.hint': {'translation': 'Activate this theme'},
            },
          },
        },
      );
    });

    tearDown(() async => f.dispose());

    test('contributes a theme.pick command', () async {
      f.services.extensions.register(ThemePickerExtension());
      await f.services.extensions.activateAll();
      expect(f.services.commands.get('theme.pick'), isNotNull);
    });

    test('default binding ctrl+k is registered', () async {
      f.services.extensions.register(ThemePickerExtension());
      await f.services.extensions.activateAll();
      expect(
        f.services.keybindings.commandFor(Keybinding.parse('ctrl+k')),
        'theme.pick',
      );
    });

    testWidgets('modal lists every bundled theme', (tester) async {
      await tester.pumpWidget(
        harness(
          f,
          ThemePickerView(
            controller: f.services.theme,
            onDismiss: ([_]) {},
          ),
        ),
      );
      // Each row renders both displayName and name; displayName==name in
      // test fixtures so the label appears twice per row.
      expect(find.text('summer-night'), findsNWidgets(2));
      expect(find.text('forest'), findsNWidgets(2));
      expect(find.text('Select theme'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('tapping a row calls controller.select + onDismiss', (tester) async {
      String? dismissed;
      await tester.pumpWidget(
        harness(
          f,
          ThemePickerView(
            controller: f.services.theme,
            onDismiss: ([v]) => dismissed = v,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('forest'));
      await tester.pumpAndSettle();
      expect(f.services.theme.currentName, 'forest');
      expect(dismissed, 'forest');
    });

    testWidgets('Cancel button dismisses without selecting', (tester) async {
      String? dismissed = 'not-called';
      await tester.pumpWidget(
        harness(
          f,
          ThemePickerView(
            controller: f.services.theme,
            onDismiss: ([v]) => dismissed = v,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Cancel'));
      await tester.pumpAndSettle();
      expect(dismissed, isNull);
    });
  });
}
