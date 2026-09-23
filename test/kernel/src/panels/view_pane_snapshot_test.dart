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

    // T-246: detail tabs report what they show, from the reader-nav selection
    // (tickets/decisions) or the active editor buffer.
    group('subject', () {
      late MessageBus bus;
      late ReaderNavRegistry navs;

      setUp(() {
        bus = MessageBus();
        navs = ReaderNavRegistry(bus);
        panels.registerSlot(const SlotDefinition(id: Slots.contextPanel, position: SlotPosition.right));
      });

      tearDown(() {
        navs.dispose();
        bus.dispose();
      });

      TabContribution detail(String id, SlotId slot, String source) =>
          TabContribution(id: id, slot: slot, title: 'Detail', subjectSource: source, build: (_) => const SizedBox.shrink());

      test('carries the reader-nav selection and the editor path; omits it elsewhere', () async {
        panels.contribute(detail('tickets.detail', Slots.contextPanel, 'builtin.tickets'));
        panels.contribute(detail('decisions.detail', Slots.contextPanel, 'builtin.decisions'));
        panels.contribute(detail('editor.active', Slots.workspace, 'builtin.editor'));
        panels.contribute(_tab('files', Slots.sidebar));
        navs.navFor('builtin.tickets', dataKey: 'id');
        navs.navFor('builtin.decisions', dataKey: 'id');
        // Selections travel the bus exactly as a sidebar click publishes them.
        bus.publish('builtin.tickets', 'selection', {'id': 'T-244'});
        bus.publish('builtin.decisions', 'selection', {'id': 'D-6'});
        await pumpEventQueue();

        final subjects = {...navs.currentByReader, 'builtin.editor': '/repo/lib/main.dart'};
        final byId = {for (final v in snapshotViewPanes(panels, arrangement, subjects: subjects)) v.id: v};
        expect(byId['tickets.detail']!.subject, 'T-244');
        expect(byId['decisions.detail']!.subject, 'D-6');
        expect(byId['editor.active']!.subject, '/repo/lib/main.dart');
        expect(byId['files']!.subject, isNull, reason: 'no subjectSource');
        expect(byId['tickets.detail']!.toJson()['subject'], 'T-244');
        expect(byId['files']!.toJson().containsKey('subject'), isFalse);
      });

      test('a declared source with nothing loaded yet has no subject', () {
        panels.contribute(detail('tickets.detail', Slots.contextPanel, 'builtin.tickets'));
        final pane = snapshotViewPanes(panels, arrangement, subjects: navs.currentByReader).single;
        expect(pane.subject, isNull);
        expect(pane.toJson().containsKey('subject'), isFalse);
      });
    });
  });
}
