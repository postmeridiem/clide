import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

TabContribution _tab({
  required String id,
  required SlotId slot,
  int priority = 0,
}) =>
    TabContribution(
      id: id,
      slot: slot,
      title: id,
      priority: priority,
      build: (_) => const SizedBox.shrink(),
    );

void main() {
  group('PanelRegistry', () {
    late PanelRegistry r;

    setUp(() => r = PanelRegistry());

    test('registerSlot creates an empty mount list', () {
      r.registerSlot(const SlotDefinition(
        id: Slots.sidebar,
        position: SlotPosition.left,
      ));
      expect(r.definitionFor(Slots.sidebar)!.position, SlotPosition.left);
      expect(r.contributionsFor(Slots.sidebar), isEmpty);
    });

    test('contribute appends to the slot and orders by priority', () {
      r.contribute(_tab(id: 'a', slot: Slots.sidebar, priority: 10));
      r.contribute(_tab(id: 'b', slot: Slots.sidebar, priority: -5));
      r.contribute(_tab(id: 'c', slot: Slots.sidebar, priority: 0));
      expect(r.tabsFor(Slots.sidebar).map((t) => t.id), ['b', 'c', 'a']);
    });

    test('first tab contribution becomes the active tab', () {
      r.contribute(_tab(id: 'a', slot: Slots.sidebar));
      expect(r.activeTabIn(Slots.sidebar), 'a');
      r.contribute(_tab(id: 'b', slot: Slots.sidebar));
      expect(r.activeTabIn(Slots.sidebar), 'a');
    });

    test('uncontribute removes by id and reassigns active tab', () {
      r.contribute(_tab(id: 'a', slot: Slots.sidebar));
      r.contribute(_tab(id: 'b', slot: Slots.sidebar));
      expect(r.activeTabIn(Slots.sidebar), 'a');
      r.uncontribute('a');
      expect(r.tabsFor(Slots.sidebar).map((t) => t.id), ['b']);
      expect(r.activeTabIn(Slots.sidebar), 'b');
    });

    test('activateTab notifies listeners', () {
      r.contribute(_tab(id: 'a', slot: Slots.sidebar));
      r.contribute(_tab(id: 'b', slot: Slots.sidebar));
      var count = 0;
      r.addListener(() => count++);
      r.activateTab(Slots.sidebar, 'b');
      expect(r.activeTabIn(Slots.sidebar), 'b');
      expect(count, 1);
    });

    test('contributing a non-slot contribution is a no-op for slots', () {
      r.contribute(CommandContribution(
        id: 'c',
        command: 'c',
        run: (_) async => throw UnimplementedError(),
      ));
      expect(r.tabsFor(Slots.sidebar), isEmpty);
    });
  });
}
