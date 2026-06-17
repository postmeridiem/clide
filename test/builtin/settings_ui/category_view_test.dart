import 'package:clide/builtin/settings_ui/settings_ui.dart';
import 'package:clide/clide.dart' show IpcResponse;
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

const _category = SettingsCategory(
  id: 'demo',
  title: 'Demo',
  iconName: 'gear',
  sections: [
    SettingsSection(
      label: 'Group',
      fields: [
        SettingsField(key: 'app.demo.flag', kind: SettingsFieldKind.toggle, label: 'Flag', defaultValue: false),
        SettingsField(
          key: 'app.demo.level',
          kind: SettingsFieldKind.select,
          label: 'Level',
          defaultValue: 'info',
          options: [
            SettingsOption(value: 'info', label: 'Info'),
            SettingsOption(value: 'debug', label: 'Debug'),
          ],
        ),
        SettingsField(key: 'app.demo.name', kind: SettingsFieldKind.text, label: 'Name', defaultValue: ''),
        SettingsField(key: 'app.demo.size', kind: SettingsFieldKind.number, label: 'Size', defaultValue: 4, min: 1, max: 8),
      ],
    ),
  ],
);

const _other = SettingsCategory(
  id: 'other',
  title: 'Other',
  sections: [
    SettingsSection(
      label: 'Misc',
      fields: [SettingsField(key: 'app.other.x', kind: SettingsFieldKind.toggle, label: 'OtherFlag', defaultValue: false)],
    ),
  ],
);

/// Tiny extension that registers [_category] via the contribution.
class _DemoSettingsExt extends ClideExtension {
  @override
  String get id => 'test.demo-settings';
  @override
  String get title => 'Demo settings';
  @override
  String get version => '1.0.0';
  @override
  List<ContributionPoint> get contributions => const [SettingsCategoryContribution(id: 'demo', category: _category)];
}

Widget _bounded(Widget child) => SizedBox(width: 620, height: 520, child: child);

Finder get _toggle => find.byWidgetPredicate((w) => w is Semantics && w.properties.checked != null);

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
  });
  tearDown(() async => f.dispose());

  group('SettingsCategoryContribution routing', () {
    test('an activated extension registers its category in the registry', () async {
      f.services.extensions.register(_DemoSettingsExt());
      await f.services.extensions.activateAll();
      expect(f.services.settingsRegistry.byId('demo')?.title, 'Demo');
    });
  });

  group('SettingsCategoryView', () {
    testWidgets('renders the section header, field labels, and current values', (tester) async {
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: _category))));
      expect(find.text('GROUP'), findsOneWidget); // small-caps section header
      expect(find.text('Flag'), findsOneWidget);
      expect(find.text('Level'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      // Select shows the default option's label when the key is unset.
      expect(find.text('Info'), findsOneWidget);
    });

    testWidgets('tapping the toggle writes the flipped value to the store', (tester) async {
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: _category))));
      expect(_toggle, findsOneWidget);
      await tester.tap(_toggle);
      await tester.pump();
      expect(f.services.settings.get<bool>('app.demo.flag'), isTrue);
    });

    testWidgets('picking a select option writes it to the store', (tester) async {
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: _category))));
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Level:')));
      await tester.pump();
      await tester.tap(find.text('Debug'));
      await tester.pump();
      expect(f.services.settings.get<String>('app.demo.level'), 'debug');
    });

    testWidgets('a select with applyCommandPrefix runs the command, not a key write', (tester) async {
      var ran = '';
      f.services.commands.register(
        CommandContribution(
          id: 'test.apply.vim',
          command: 'test.apply.vim',
          run: (_) async {
            ran = 'vim';
            return IpcResponse.ok(id: '', data: const {});
          },
        ),
      );
      const cat = SettingsCategory(
        id: 'k',
        title: 'K',
        sections: [
          SettingsSection(
            label: 'P',
            fields: [
              SettingsField(
                key: 'app.k.preset',
                kind: SettingsFieldKind.select,
                label: 'Preset',
                defaultValue: 'default',
                applyCommandPrefix: 'test.apply.',
                options: [SettingsOption(value: 'default', label: 'Default'), SettingsOption(value: 'vim', label: 'Vim')],
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: cat))));
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Preset:')));
      await tester.pump();
      await tester.tap(find.text('Vim'));
      await tester.pump();
      expect(ran, 'vim');
      // The key is applied by the command, not written directly by the engine.
      expect(f.services.settings.get<String>('app.k.preset'), isNull);
    });
  });

  group('scope tag (T-449)', () {
    testWidgets('an unset field shows the Default scope tag', (tester) async {
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: _category))));
      expect(find.bySemanticsLabel('Size scope: Default'), findsOneWidget);
    });

    testWidgets('a value stored at app scope shows the All clide tag', (tester) async {
      await tester.runAsync(() => f.services.settings.set('app.demo.flag', true));
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: _category))));
      expect(find.bySemanticsLabel('Flag scope: All clide'), findsOneWidget);
    });

    testWidgets('the scope menu resets the value to default', (tester) async {
      await tester.runAsync(() => f.services.settings.set('app.demo.flag', true));
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: _category))));
      await tester.tap(find.bySemanticsLabel('Flag scope: All clide'));
      await tester.pump();
      await tester.tap(find.text('Reset to default'));
      await tester.pump();
      expect(f.services.settings.effectiveLayer('app.demo.flag'), isNull);
    });
  });

  group('SettingsModal with a registered category', () {
    testWidgets('renders the category instead of the empty state', (tester) async {
      f.services.settingsRegistry.register(_category);
      await tester.pumpWidget(harness(f, SettingsModal(onDismiss: () {})));
      expect(find.text('Flag'), findsOneWidget);
      expect(find.text('No settings categories are registered yet.'), findsNothing);
    });

    testWidgets('rail lists categories and selecting one swaps the panel', (tester) async {
      f.services.settingsRegistry.register(_category);
      f.services.settingsRegistry.register(_other);
      await tester.pumpWidget(harness(f, SettingsModal(onDismiss: () {})));
      // Rail shows both titles; first (alphabetical) category's panel is shown.
      expect(find.text('Demo'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Flag'), findsOneWidget);
      expect(find.text('OtherFlag'), findsNothing);
      // Selecting the second category swaps the panel.
      await tester.tap(find.text('Other'));
      await tester.pump();
      expect(find.text('OtherFlag'), findsOneWidget);
      expect(find.text('Flag'), findsNothing);
    });

    testWidgets('searching filters fields across categories with rail counts', (tester) async {
      f.services.settingsRegistry.register(_category);
      f.services.settingsRegistry.register(_other);
      await tester.pumpWidget(harness(f, SettingsModal(onDismiss: () {})));
      final box = find.descendant(of: find.byType(ClideFilterBox), matching: find.byType(EditableText));
      await tester.enterText(box, 'Other');
      await tester.pump(const Duration(milliseconds: 250)); // past the filter debounce
      await tester.pump();
      // Only the matching field (in the Other category) is shown.
      expect(find.text('OtherFlag'), findsOneWidget);
      expect(find.text('Flag'), findsNothing);
      // The rail shows the Other category's match count.
      expect(find.text('1'), findsOneWidget);
    });
  });
}
