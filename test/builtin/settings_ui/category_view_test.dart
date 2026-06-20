import 'dart:io';

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
                options: [
                  SettingsOption(value: 'default', label: 'Default'),
                  SettingsOption(value: 'vim', label: 'Vim'),
                ],
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

  group('custom field (T-452)', () {
    testWidgets('renders the control registered for its customId, full-width with its label', (tester) async {
      f.services.settingsControlRegistry.register('probe', (_) => const ClideText('PROBE-CONTROL'));
      const cat = SettingsCategory(
        id: 'c',
        title: 'C',
        sections: [
          SettingsSection(
            label: 'S',
            fields: [SettingsField(key: 'app.c.x', kind: SettingsFieldKind.custom, label: 'Custom', customId: 'probe')],
          ),
        ],
      );
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: cat))));
      expect(find.text('PROBE-CONTROL'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
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

    testWidgets('a value stored at project scope shows the This project tag', (tester) async {
      // project.* keys live only in the project layer, which needs a project dir
      // open. Point the store at a temp dir and write the key there at project
      // scope so _appearance(SettingsScope.project) renders (lines 560-562).
      const projCat = SettingsCategory(
        id: 'pj',
        title: 'PJ',
        sections: [
          SettingsSection(
            label: 'S',
            fields: [SettingsField(key: 'project.pj.flag', kind: SettingsFieldKind.toggle, label: 'ProjFlag', defaultValue: false)],
          ),
        ],
      );
      late Directory projDir;
      await tester.runAsync(() async {
        projDir = await Directory.systemTemp.createTemp('clide_scope_');
        await f.services.settings.setProjectDir(projDir);
        await f.services.settings.setAt(SettingsScope.project, 'project.pj.flag', true);
      });
      addTearDown(() async {
        if (await projDir.exists()) {
          try {
            await projDir.delete(recursive: true);
          } catch (_) {}
        }
      });
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: projCat))));
      expect(find.bySemanticsLabel('ProjFlag scope: This project'), findsOneWidget);
    });

    testWidgets('moving an unset value to All clide writes it at app scope', (tester) async {
      // _other's key (app.other.x) is written by no other test → pristine here.
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: _other))));
      await tester.tap(find.bySemanticsLabel('OtherFlag scope: Default'));
      await tester.pump();
      await tester.tap(find.text('All clide'));
      await tester.pump();
      expect(f.services.settings.effectiveLayer('app.other.x'), SettingsScope.app);
    });
  });

  group('edit controls (T-448)', () {
    const numCat = SettingsCategory(
      id: 'n',
      title: 'N',
      sections: [
        SettingsSection(
          label: 'S',
          fields: [SettingsField(key: 'app.n.size', kind: SettingsFieldKind.number, label: 'Size', defaultValue: 4, min: 1, max: 8)],
        ),
      ],
    );
    const textCat = SettingsCategory(
      id: 't',
      title: 'T',
      sections: [
        SettingsSection(
          label: 'S',
          fields: [SettingsField(key: 'app.t.name', kind: SettingsFieldKind.text, label: 'Name', defaultValue: '')],
        ),
      ],
    );

    testWidgets('a number field commits a valid value', (tester) async {
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: numCat))));
      await tester.enterText(find.byType(EditableText), '6');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(f.services.settings.get<num>('app.n.size'), 6);
    });

    testWidgets('a number field clamps above max and below min', (tester) async {
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: numCat))));
      await tester.enterText(find.byType(EditableText), '99');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(f.services.settings.get<num>('app.n.size'), 8);
      await tester.enterText(find.byType(EditableText), '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(f.services.settings.get<num>('app.n.size'), 1);
    });

    testWidgets('a number field reverts unparseable input without writing', (tester) async {
      // Dedicated key — the store is shared across tests in this file, so a key
      // the commit/clamp tests touch would already be set.
      const revCat = SettingsCategory(
        id: 'nr',
        title: 'NR',
        sections: [
          SettingsSection(
            label: 'S',
            fields: [SettingsField(key: 'app.nr.size', kind: SettingsFieldKind.number, label: 'Size', defaultValue: 4, min: 1, max: 8)],
          ),
        ],
      );
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: revCat))));
      await tester.enterText(find.byType(EditableText), 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      // Unparseable input is reverted to the field's value, not committed; the
      // string 'abc' never reaches the store.
      expect(find.text('4'), findsOneWidget);
      expect(f.services.settings.get<Object>('app.nr.size'), isNot('abc'));
    });

    testWidgets('a text field reflects an external value change when not focused (didUpdateWidget)', (tester) async {
      // Dedicated key — the store is shared across tests in this file.
      const extCat = SettingsCategory(
        id: 'tx',
        title: 'TX',
        sections: [
          SettingsSection(
            label: 'S',
            fields: [SettingsField(key: 'app.tx.name', kind: SettingsFieldKind.text, label: 'Name', defaultValue: 'initial')],
          ),
        ],
      );
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: extCat))));
      expect(find.text('initial'), findsOneWidget);
      // External write (e.g. a reset or another surface) with the field unfocused
      // → the ListenableBuilder rebuilds _EditControl with a new value, and
      // didUpdateWidget pushes it into the controller (lines 433-438).
      await tester.runAsync(() => f.services.settings.set('app.tx.name', 'updated'));
      await tester.pump();
      expect(find.text('updated'), findsOneWidget);
    });

    testWidgets('a text field commits the trimmed value', (tester) async {
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: textCat))));
      await tester.enterText(find.byType(EditableText), '  hello  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(f.services.settings.get<String>('app.t.name'), 'hello');
    });

    testWidgets('a select shows the raw stored value when it is not among the options', (tester) async {
      await tester.runAsync(() => f.services.settings.set('app.demo.level', 'trace'));
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: _category))));
      expect(find.text('trace'), findsOneWidget);
    });

    testWidgets('a file field renders a button that runs its command', (tester) async {
      var ran = false;
      f.services.commands.register(
        CommandContribution(
          id: 'test.openfile',
          command: 'test.openfile',
          run: (_) async {
            ran = true;
            return IpcResponse.ok(id: '', data: const {});
          },
        ),
      );
      const cat = SettingsCategory(
        id: 'fc',
        title: 'FC',
        sections: [
          SettingsSection(
            label: 'S',
            fields: [SettingsField(key: 'app.fc.cfg', kind: SettingsFieldKind.file, label: 'Edit config', fileCommand: 'test.openfile')],
          ),
        ],
      );
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: cat))));
      await tester.tap(find.widgetWithText(ClideButton, 'Edit config'));
      await tester.pump();
      expect(ran, isTrue);
    });

    testWidgets('a field renders its help text', (tester) async {
      const cat = SettingsCategory(
        id: 'h',
        title: 'H',
        sections: [
          SettingsSection(
            label: 'S',
            fields: [SettingsField(key: 'app.h.flag', kind: SettingsFieldKind.toggle, label: 'Flag', help: 'Toggle the thing', defaultValue: false)],
          ),
        ],
      );
      await tester.pumpWidget(harness(f, _bounded(const SettingsCategoryView(category: cat))));
      expect(find.text('Toggle the thing'), findsOneWidget);
    });

    testWidgets('search results show an empty state when nothing matches', (tester) async {
      f.services.settingsRegistry.register(_category);
      await tester.pumpWidget(harness(f, _bounded(const SettingsSearchResults(query: 'zzznomatch'))));
      expect(find.text('No settings match your search.'), findsOneWidget);
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

  group('i18n localization (T-462)', () {
    testWidgets('section/field/help labels resolve through the category namespace', (tester) async {
      // KernelFixture.create does real temp-dir I/O; run it on the real event
      // loop (not the fake-async testWidgets body) or it traps under load (T-122).
      late KernelFixture lf;
      await tester.runAsync(
        () async => lf = await KernelFixture.create(
          i18nCatalogs: {
            'test.loc': {
              const Locale('en', 'US'): const {
                'sec.label': {'translation': 'LOCSEC'},
                'fld.label': {'translation': 'LocField'},
                'fld.help': {'translation': 'LocHelp'},
                'sel.label': {'translation': 'LocSelect'},
                'opt.a': {'translation': 'LocOptA'},
              },
            },
          },
        ),
      );
      addTearDown(lf.dispose);
      const cat = SettingsCategory(
        id: 'loc',
        title: 'EngCat',
        i18nNamespace: 'test.loc',
        sections: [
          SettingsSection(
            label: 'EngSec',
            labelKey: 'sec.label',
            fields: [
              SettingsField(
                key: 'app.loc.flag',
                kind: SettingsFieldKind.toggle,
                label: 'EngField',
                labelKey: 'fld.label',
                help: 'EngHelp',
                helpKey: 'fld.help',
                defaultValue: false,
              ),
              SettingsField(
                key: 'app.loc.sel',
                kind: SettingsFieldKind.select,
                label: 'EngSelect',
                labelKey: 'sel.label',
                defaultValue: 'a',
                options: [SettingsOption(value: 'a', label: 'EngOptA', labelKey: 'opt.a')],
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(harness(lf, _bounded(const SettingsCategoryView(category: cat))));
      expect(find.text('LOCSEC'), findsOneWidget); // section header from the catalog
      expect(find.text('LocField'), findsOneWidget); // field label localized
      expect(find.text('LocHelp'), findsOneWidget); // help localized
      expect(find.text('LocSelect'), findsOneWidget); // select field label localized
      expect(find.text('LocOptA'), findsOneWidget); // select shows the localized current option
      expect(find.text('EngField'), findsNothing); // English placeholder replaced
    });
  });
}
