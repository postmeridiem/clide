import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

/// Tier-0 smoke — each interactive primitive can *hold* focus when a
/// [Focus] wraps it, and Semantics reports the right tap action. Full
/// Tab-traversal order lives in `integration_test/app_starts_test.dart`
/// where the real WidgetsApp + DefaultFocusTraversal are present.
void main() {
  group('keyboard focusability', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('ClideButton can be programmatically focused', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          f,
          Focus(
            focusNode: node,
            child: ClideButton(label: 'Save', onPressed: () {}),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
    });

    testWidgets('interactive widgets expose tap actions to a11y',
        (tester) async {
      await tester.pumpWidget(
        harness(f, ClideButton(label: 'Save', onPressed: () {})),
      );
      final handle = tester.ensureSemantics();
      final data =
          tester.getSemantics(find.byType(ClideButton)).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });
}
