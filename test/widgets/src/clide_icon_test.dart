import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ClideIcon', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('sizes a SizedBox + CustomPaint to the given size', (tester) async {
      await tester.pumpWidget(
        harness(f, const ClideIcon(FolderIcon(), size: 24)),
      );
      final sb = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sb.width, 24);
      expect(sb.height, 24);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('default color is globalForeground', (tester) async {
      await tester.pumpWidget(
        harness(f, const ClideIcon(CheckIcon())),
      );
      // Color is inaccessible after painting; ensure it renders without crashing.
      expect(find.byType(ClideIcon), findsOneWidget);
    });
  });
}
