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
      expect(
          f.services.arrangement.positionOf(Slots.sidebar), SlotPosition.left);
      expect(f.services.arrangement.sizeOf(Slots.sidebar), 240);
      expect(f.services.arrangement.positionOf(Slots.workspace),
          SlotPosition.center);
      expect(f.services.arrangement.positionOf(Slots.statusbar),
          SlotPosition.bottom);
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
      expect(f.services.arrangement.sizeOf(Slots.sidebar), 240);
    });

    test('declares a layout preset contribution', () {
      final ext = DefaultLayoutExtension();
      expect(
        ext.contributions.whereType<LayoutPresetContribution>(),
        hasLength(1),
      );
    });
  });
}
