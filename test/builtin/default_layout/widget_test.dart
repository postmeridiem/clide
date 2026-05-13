import 'package:clide/builtin/default_layout/default_layout.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  group('DefaultLayoutExtension', () {
    late KernelFixture f;

    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    test('activates and applies the classic preset', () async {
      f.services.extensions.register(DefaultLayoutExtension());
      await f.services.extensions.activateAll();
      expect(f.services.arrangement.positionOf(Slots.sidebar), SlotPosition.left);
      expect(f.services.arrangement.sizeOf(Slots.sidebar), 400);
      expect(f.services.arrangement.positionOf(Slots.workspace), SlotPosition.center);
      expect(f.services.arrangement.positionOf(Slots.statusbar), SlotPosition.bottom);
    });

    test('contributes a layout.reset command', () async {
      f.services.extensions.register(DefaultLayoutExtension());
      await f.services.extensions.activateAll();
      final reset = f.services.commands.get('layout.reset');
      expect(reset, isNotNull);
    });

    test('layout.reset re-applies the preset', () async {
      f.services.extensions.register(DefaultLayoutExtension());
      await f.services.extensions.activateAll();
      f.services.arrangement.setSize(Slots.sidebar, 300);
      expect(f.services.arrangement.sizeOf(Slots.sidebar), 300);
      final resp = await f.services.commands.execute('layout.reset');
      expect(resp.ok, true);
      expect(f.services.arrangement.sizeOf(Slots.sidebar), 400);
    });

    test('declares a layout preset contribution', () {
      final ext = DefaultLayoutExtension();
      expect(
        ext.contributions.whereType<LayoutPresetContribution>(),
        hasLength(1),
      );
    });

    test('all commands return not-activated errors before activate', () async {
      final ext = DefaultLayoutExtension();
      final cmds = ext.contributions.whereType<CommandContribution>().toList();
      // 12+ commands including the 5 sidebar.section.N variants.
      expect(cmds.length, greaterThan(10));
      for (final cmd in cmds) {
        final r = await cmd.run(const []);
        expect(r.ok, isFalse, reason: 'expected ${cmd.command} to fail pre-activate');
        expect(r.error!.message, contains('not activated'));
      }
    });

    test('palette.toggle flips palette open state', () async {
      f.services.extensions.register(DefaultLayoutExtension());
      await f.services.extensions.activateAll();
      expect(f.services.palette.isOpen, isFalse);
      final r1 = await f.services.commands.execute('palette.toggle');
      expect(r1.ok, isTrue);
      expect(r1.data['open'], isTrue);
      expect(f.services.palette.isOpen, isTrue);
      final r2 = await f.services.commands.execute('palette.toggle');
      expect(r2.data['open'], isFalse);
    });

    test('sidebar.collapse + context.collapse toggle their respective slots', () async {
      f.services.extensions.register(DefaultLayoutExtension());
      await f.services.extensions.activateAll();
      expect(f.services.arrangement.isCollapsed(Slots.sidebar), isFalse);
      await f.services.commands.execute('sidebar.collapse');
      expect(f.services.arrangement.isCollapsed(Slots.sidebar), isTrue);
      await f.services.commands.execute('sidebar.collapse');
      expect(f.services.arrangement.isCollapsed(Slots.sidebar), isFalse);
      await f.services.commands.execute('context.collapse');
      expect(f.services.arrangement.isCollapsed(Slots.contextPanel), isTrue);
    });

    test('panel.focus.{left,middle,right} expand collapsed sides + set focus', () async {
      f.services.extensions.register(DefaultLayoutExtension());
      await f.services.extensions.activateAll();
      // Collapse both side panels first.
      f.services.arrangement.setCollapsed(Slots.sidebar, true);
      f.services.arrangement.setCollapsed(Slots.contextPanel, true);
      // Focus left: re-expands sidebar.
      await f.services.commands.execute('panel.focus.left');
      expect(f.services.arrangement.isCollapsed(Slots.sidebar), isFalse);
      // Focus right: re-expands context.
      await f.services.commands.execute('panel.focus.right');
      expect(f.services.arrangement.isCollapsed(Slots.contextPanel), isFalse);
      // Focus middle: no expansion needed, just sets focus.
      final r = await f.services.commands.execute('panel.focus.middle');
      expect(r.ok, isTrue);
    });

    test('panel.focusMode toggles focus mode on the active slot', () async {
      f.services.extensions.register(DefaultLayoutExtension());
      await f.services.extensions.activateAll();
      expect(f.services.arrangement.isInFocusMode, isFalse);
      await f.services.commands.execute('panel.focusMode');
      expect(f.services.arrangement.isInFocusMode, isTrue);
    });

    test('panel.focusMode.exit unwinds focus-mode → editor → palette', () async {
      f.services.extensions.register(DefaultLayoutExtension());
      await f.services.extensions.activateAll();
      // Focus mode: exit clears it.
      f.services.arrangement.toggleFocusMode(Slots.workspace);
      expect(f.services.arrangement.isInFocusMode, isTrue);
      await f.services.commands.execute('panel.focusMode.exit');
      expect(f.services.arrangement.isInFocusMode, isFalse);
      // Editor open: exit closes it.
      f.services.arrangement.openEditor();
      expect(f.services.arrangement.editorOpen, isTrue);
      await f.services.commands.execute('panel.focusMode.exit');
      expect(f.services.arrangement.editorOpen, isFalse);
      // Palette open: exit closes it.
      f.services.palette.toggle();
      expect(f.services.palette.isOpen, isTrue);
      await f.services.commands.execute('panel.focusMode.exit');
      expect(f.services.palette.isOpen, isFalse);
      // Nothing to exit: returns ok with empty data.
      final noop = await f.services.commands.execute('panel.focusMode.exit');
      expect(noop.ok, isTrue);
    });

    test('editor.open and editor.close toggle the editor split', () async {
      f.services.extensions.register(DefaultLayoutExtension());
      await f.services.extensions.activateAll();
      expect(f.services.arrangement.editorOpen, isFalse);
      await f.services.commands.execute('editor.open');
      expect(f.services.arrangement.editorOpen, isTrue);
      await f.services.commands.execute('editor.close');
      expect(f.services.arrangement.editorOpen, isFalse);
      // editor.close when already closed → ok no-op.
      final noop = await f.services.commands.execute('editor.close');
      expect(noop.ok, isTrue);
    });

    test('sidebar.section.N activates the Nth sidebar tab', () async {
      f.services.extensions.register(DefaultLayoutExtension());
      await f.services.extensions.activateAll();
      // Collapse sidebar so we exercise the re-expand branch.
      f.services.arrangement.setCollapsed(Slots.sidebar, true);
      // No-op when no tabs are contributed.
      final r = await f.services.commands.execute('sidebar.section.1');
      expect(r.ok, isTrue);
      // Sidebar auto-expanded.
      expect(f.services.arrangement.isCollapsed(Slots.sidebar), isFalse);
    });
  });
}
