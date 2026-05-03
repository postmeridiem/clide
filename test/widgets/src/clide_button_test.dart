import 'package:clide/widgets/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ClideButton', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create();
    });

    tearDown(() async {
      await f.dispose();
    });

    testWidgets('renders the label text', (tester) async {
      await tester.pumpWidget(
        harness(f, const ClideButton(label: 'Save', onPressed: null)),
      );
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('emits a Semantics node with button: true + label', (tester) async {
      await tester.pumpWidget(
        harness(f, ClideButton(label: 'Commit', onPressed: () {})),
      );
      final semantics = tester.getSemantics(find.byType(ClideButton));
      expect(semantics.label, 'Commit');
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'enabled button must expose tap action',
      );
    });

    testWidgets('semanticLabel overrides the visible label for a11y', (tester) async {
      await tester.pumpWidget(
        harness(
          f,
          ClideButton(
            label: 'Save',
            semanticLabel: 'Save document',
            onPressed: () {},
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(ClideButton));
      expect(semantics.label, 'Save document');
    });

    testWidgets('semanticHint propagates to the Semantics node', (tester) async {
      await tester.pumpWidget(
        harness(
          f,
          ClideButton(
            label: 'Pick',
            semanticHint: 'Select a theme',
            onPressed: () {},
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(ClideButton));
      expect(semantics.hint, 'Select a theme');
    });

    testWidgets('disabled button drops the tap action', (tester) async {
      await tester.pumpWidget(
        harness(f, const ClideButton(label: 'Nope', onPressed: null)),
      );
      final semantics = tester.getSemantics(find.byType(ClideButton));
      expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    });

    testWidgets('tap invokes onPressed', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        harness(
          f,
          ClideButton(label: 'Go', onPressed: () => pressed++),
        ),
      );
      await tester.tap(find.byType(ClideButton));
      expect(pressed, 1);
    });
  });
}
