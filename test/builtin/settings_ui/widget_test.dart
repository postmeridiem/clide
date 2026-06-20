import 'package:clide/builtin/settings_ui/settings_ui.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('SettingsUiExtension', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create(
        i18nCatalogs: {
          'builtin.settings-ui': {
            const Locale('en', 'US'): const {
              'modal.title': {'translation': 'Settings'},
              'modal.close': {'translation': 'Close'},
              'modal.close.hint': {'translation': 'Close settings'},
              'rail.header': {'translation': 'Categories'},
              'panel.empty': {'translation': 'No settings categories are registered yet.'},
            },
          },
          // Namespace for a category whose rail title resolves via titleKey.
          'test.railcat': {
            const Locale('en', 'US'): const {
              'cat.title': {'translation': 'Localized Rail'},
            },
          },
        },
      );
    });

    tearDown(() async => f.dispose());

    test('contributes a settings.open command', () async {
      f.services.extensions.register(SettingsUiExtension());
      await f.services.extensions.activateAll();
      expect(f.services.commands.get('settings.open'), isNotNull);
    });

    test('default binding ctrl+, is registered', () async {
      f.services.extensions.register(SettingsUiExtension());
      await f.services.extensions.activateAll();
      expect(f.services.keybindings.commandFor(Keybinding.parse('ctrl+,')), 'settings.open');
    });

    testWidgets('modal shell renders title, rail header, and empty state', (tester) async {
      await tester.pumpWidget(harness(f, SettingsModal(onDismiss: () {})));
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('No settings categories are registered yet.'), findsOneWidget);
    });

    testWidgets('Esc dismisses the modal', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(harness(f, SettingsModal(onDismiss: () => dismissed++)));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('close button dismisses the modal', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(harness(f, SettingsModal(onDismiss: () => dismissed++)));
      // The close button carries the "Close" semantics label.
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('a rail row resolves its title via titleKey + namespace (T-462)', (tester) async {
      // A category with titleKey + i18nNamespace → the rail localizes the row
      // title through the catalog instead of the English fallback (line 251).
      f.services.settingsRegistry.register(
        const SettingsCategory(
          id: 'railcat',
          title: 'EngRail',
          titleKey: 'cat.title',
          i18nNamespace: 'test.railcat',
          sections: [
            SettingsSection(
              label: 'S',
              fields: [SettingsField(key: 'app.railcat.flag', kind: SettingsFieldKind.toggle, label: 'F', defaultValue: false)],
            ),
          ],
        ),
      );
      await tester.pumpWidget(harness(f, SettingsModal(onDismiss: () {})));
      expect(find.text('Localized Rail'), findsOneWidget);
      expect(find.text('EngRail'), findsNothing);
    });
  });
}
