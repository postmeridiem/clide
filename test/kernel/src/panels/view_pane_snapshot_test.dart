/// Tests for [snapshotViewPanes] — the kernel→ViewPane bridge that lets
/// `pane list` reflect the GUI tabs the user sees (T-219, D-83).
library;

import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

TabContribution _tab(String id, SlotId slot) => TabContribution(id: id, slot: slot, title: id.toUpperCase(), build: (_) => const SizedBox.shrink());

void main() {
  group('snapshotViewPanes', () {
    late PanelRegistry panels;
    late LayoutArrangement arrangement;

    setUp(() {
      panels = PanelRegistry();
      arrangement = LayoutArrangement();
      panels.registerSlot(const SlotDefinition(id: Slots.workspace, position: SlotPosition.center));
      panels.registerSlot(const SlotDefinition(id: Slots.sidebar, position: SlotPosition.left));
    });

    test('one ViewPane per tab, tagged with slot, title and active state', () {
      panels.contribute(_tab('claude', Slots.workspace));
      panels.contribute(_tab('editor', Slots.workspace));
      panels.contribute(_tab('files', Slots.sidebar));

      final panesById = {for (final v in snapshotViewPanes(panels, arrangement)) v.id: v};
      expect(panesById.keys, containsAll(['claude', 'editor', 'files']));
      expect(panesById['claude']!.slot, 'workspace');
      expect(panesById['claude']!.title, 'CLAUDE');
      // first tab in a slot is the active one
      expect(panesById['claude']!.active, isTrue);
      expect(panesById['editor']!.active, isFalse);
      expect(panesById['files']!.active, isTrue);
    });

    test('active follows the kernel activeTab; visible follows the arrangement', () {
      arrangement.applyPreset(
        const LayoutPresetContribution(
          id: 'test',
          displayName: 'Test',
          slots: [LayoutSlot(slot: Slots.workspace, position: SlotPosition.center, visible: true)],
        ),
      );
      panels.contribute(_tab('claude', Slots.workspace));
      panels.contribute(_tab('editor', Slots.workspace));
      panels.activateTab(Slots.workspace, 'editor');

      var panesById = {for (final v in snapshotViewPanes(panels, arrangement)) v.id: v};
      expect(panesById['editor']!.active, isTrue);
      expect(panesById['claude']!.active, isFalse);
      expect(panesById['editor']!.visible, isTrue);

      // Hiding the slot is reflected on the next snapshot (read-at-request).
      arrangement.setVisible(Slots.workspace, false);
      panesById = {for (final v in snapshotViewPanes(panels, arrangement)) v.id: v};
      expect(panesById['editor']!.visible, isFalse);
    });

    test('empty when no tabs are contributed', () {
      expect(snapshotViewPanes(panels, arrangement), isEmpty);
    });
  });
}
