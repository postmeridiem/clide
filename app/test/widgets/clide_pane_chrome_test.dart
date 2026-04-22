import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  group('ClidePaneChrome', () {
    late KernelFixture f;
    setUp(() async {
      f = await KernelFixture.create();
    });
    tearDown(() => f.dispose());

    testWidgets('renders title + subtitle', (tester) async {
      await tester.pumpWidget(
        harness(
          f,
          const ClidePaneChrome(
            title: 'terminal — ~/clide',
            subtitle: 'bash · 80×24',
            child: SizedBox.shrink(),
          ),
        ),
      );
      expect(find.text('terminal — ~/clide'), findsOneWidget);
      expect(find.text('bash · 80×24'), findsOneWidget);
    });

    testWidgets('no close button when onClose is null', (tester) async {
      await tester.pumpWidget(
        harness(
          f,
          const ClidePaneChrome(
            title: 'primary claude',
            child: SizedBox.shrink(),
          ),
        ),
      );
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Close pane'), findsNothing);
      handle.dispose();
    });

    testWidgets('close button invokes onClose when present', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        harness(
          f,
          ClidePaneChrome(
            title: 'terminal',
            onClose: () => pressed = true,
            child: const SizedBox.shrink(),
          ),
        ),
      );
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Close pane'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close pane'));
      expect(pressed, isTrue);
      handle.dispose();
    });
  });
}
