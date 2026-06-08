/// Tests for ClideMenu + ClideMenuListController (D-88): list-nav skipping
/// disabled/separators, select fires onSelect+onClose, keepOpenOnSelect, Esc.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ClideMenuListController', () {
    test('moveNext/movePrev skip non-selectable and wrap', () {
      const sel = {0, 3, 4}; // 1=separator, 2=disabled
      final c = ClideMenuListController(isSelectable: (i) => sel.contains(i), length: 5);
      expect(c.highlighted, -1);
      c.moveNext();
      expect(c.highlighted, 0);
      c.moveNext();
      expect(c.highlighted, 3);
      c.moveNext();
      expect(c.highlighted, 4);
      c.moveNext();
      expect(c.highlighted, 0, reason: 'wraps to first selectable');
      c.movePrev();
      expect(c.highlighted, 4, reason: 'wraps back to last selectable');
    });

    test('movePrev from none selects the last selectable', () {
      final c = ClideMenuListController(isSelectable: (_) => true, length: 3);
      c.movePrev();
      expect(c.highlighted, 2);
    });

    test('wrap:false stops at the ends', () {
      final c = ClideMenuListController(isSelectable: (_) => true, length: 3, wrap: false);
      c.moveNext();
      c.moveNext();
      c.moveNext();
      expect(c.highlighted, 2);
      c.moveNext();
      expect(c.highlighted, 2, reason: 'no wrap');
    });

    test('length resize clears a now-out-of-range highlight', () {
      final c = ClideMenuListController(isSelectable: (_) => true, length: 5);
      c.setHighlight(4);
      c.length = 3;
      expect(c.highlighted, -1);
    });
  });

  group('ClideMenu', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('renders items + separator; tapping an item fires onSelect + onClose', (tester) async {
      var picked = '';
      var closed = 0;
      await tester.pumpWidget(harness(
        f,
        ClideMenu(
          onClose: () => closed++,
          entries: [
            ClideMenuItem(label: 'Alpha', onSelect: () => picked = 'Alpha'),
            const ClideMenuSeparator(),
            ClideMenuItem(label: 'Beta', onSelect: () => picked = 'Beta'),
          ],
        ),
      ));
      await tester.pump();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      await tester.tap(find.text('Beta'));
      await tester.pump();
      expect(picked, 'Beta');
      expect(closed, 1);
    });

    testWidgets('arrow-down then Enter activates the highlighted item', (tester) async {
      var picked = '';
      await tester.pumpWidget(harness(
        f,
        ClideMenu(
          onClose: () {},
          entries: [
            ClideMenuItem(label: 'One', onSelect: () => picked = 'One'),
            ClideMenuItem(label: 'Two', onSelect: () => picked = 'Two'),
          ],
        ),
      ));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(picked, 'Two');
    });

    testWidgets('disabled item is inert and skipped by arrows', (tester) async {
      var picked = '';
      await tester.pumpWidget(harness(
        f,
        ClideMenu(
          onClose: () {},
          entries: [
            ClideMenuItem(label: 'Able', onSelect: () => picked = 'Able'),
            ClideMenuItem(label: 'Off', enabled: false, onSelect: () => picked = 'Off'),
            ClideMenuItem(label: 'Last', onSelect: () => picked = 'Last'),
          ],
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Off'));
      await tester.pump();
      expect(picked, '', reason: 'disabled tap is a no-op');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // -> Able
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // skip Off -> Last
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(picked, 'Last');
    });

    testWidgets('Escape calls onClose', (tester) async {
      var closed = 0;
      await tester.pumpWidget(harness(f, ClideMenu(onClose: () => closed++, entries: [ClideMenuItem(label: 'X', onSelect: () {})])));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(closed, 1);
    });

    testWidgets('keepOpenOnSelect item fires onSelect but not onClose', (tester) async {
      var picked = 0;
      var closed = 0;
      await tester.pumpWidget(harness(
        f,
        ClideMenu(
          onClose: () => closed++,
          entries: [ClideMenuItem(label: 'Toggle', keepOpenOnSelect: true, onSelect: () => picked++)],
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Toggle'));
      await tester.pump();
      expect(picked, 1);
      expect(closed, 0);
    });
  });
}
