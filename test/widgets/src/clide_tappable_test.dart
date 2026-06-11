/// Widget tests for the keyboard-operable [ClideTappable] (T-100).
///
/// The pre-T-100 widget was mouse-only — these tests assert it now
/// accepts focus, that Enter / Space invoke onTap via the
/// [ActivateIntent] action, and that the focus ring appears when
/// the widget has focus.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ClideTappable — keyboard', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('accepts Tab focus when onTap is provided', (tester) async {
      var tapped = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          f,
          Center(
            child: ClideTappable(focusNode: node, onTap: () => tapped++, builder: (_, hovered, pressed) => const SizedBox(width: 60, height: 24)),
          ),
        ),
      );

      expect(node.hasFocus, isFalse);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      // Tap count unchanged — focus alone doesn't invoke.
      expect(tapped, 0);
    });

    testWidgets('Enter on a focused tappable invokes onTap via ActivateIntent', (tester) async {
      var tapped = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          f,
          Center(
            child: ClideTappable(
              focusNode: node,
              autofocus: true,
              onTap: () => tapped++,
              builder: (_, hovered, pressed) => const SizedBox(width: 60, height: 24),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(node.hasFocus, isTrue);
      // Dispatch ActivateIntent directly against the focused context
      // — mirrors what KeymapService.resolveEvent → Actions.maybeInvoke
      // would do on Enter / Space.
      Actions.invoke(node.context!, const ActivateIntent());
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('disabled tappable (onTap == null) cannot receive focus', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          f,
          Center(
            child: ClideTappable(focusNode: node, onTap: null, builder: (_, hovered, pressed) => const SizedBox(width: 60, height: 24)),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse, reason: 'canRequestFocus is false when onTap is null');
    });

    testWidgets('focus ring appears when focused, gone when unfocused', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          f,
          Center(
            child: ClideTappable(focusNode: node, onTap: () {}, builder: (_, hovered, pressed) => const SizedBox(width: 60, height: 24)),
          ),
        ),
      );

      Iterable<Color> ringColors() => tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(ClideTappable), matching: find.byType(DecoratedBox)))
          .map((d) => ((d.decoration as BoxDecoration).border?.top.color ?? const Color(0x00000000)));

      // Unfocused: no DecoratedBox descendant carries a non-transparent border.
      expect(ringColors().any((c) => c.a > 0), isFalse);

      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(ringColors().any((c) => c.a > 0), isTrue, reason: 'focus ring border should become opaque on focus');
    });
  });
}
