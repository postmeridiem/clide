import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContributionPoint sealed hierarchy', () {
    test('TabContribution exposes slot + title + i18n fields', () {
      final t = TabContribution(
        id: 'welcome.view',
        slot: Slots.workspace,
        title: 'Welcome',
        titleKey: 'tab.title',
        i18nNamespace: 'builtin.welcome',
        priority: -100,
        build: (_) => const SizedBox.shrink(),
      );
      expect(t.id, 'welcome.view');
      expect(t.slot, Slots.workspace);
      expect(t.title, 'Welcome');
      expect(t.titleKey, 'tab.title');
      expect(t.i18nNamespace, 'builtin.welcome');
      expect(t.priority, -100);
    });

    test('StatusItemContribution pins the statusbar slot', () {
      final s = StatusItemContribution(
        id: 'ipc-status.indicator',
        build: (_) => const SizedBox.shrink(),
      );
      expect(s.slot, Slots.statusbar);
    });

    test('CommandContribution has no slot', () {
      final c = CommandContribution(
        id: 'theme.pick',
        command: 'theme.pick',
        run: (_) async => IpcResponse.ok(id: '', data: const {}),
      );
      expect(c.slot, isNull);
    });

    test('TrayItemContribution pins the tray slot', () {
      final t = TrayItemContribution(
        id: 't',
        label: 'Label',
        onSelected: () {},
      );
      expect(t.slot, Slots.tray);
    });

    test('ToolbarButtonContribution pins the toolbar slot', () {
      final b = ToolbarButtonContribution(
        id: 'save',
        label: 'Save',
        onPressed: () {},
      );
      expect(b.slot, Slots.toolbar);
    });
  });
}
