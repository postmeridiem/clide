import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ClideDivider', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('renders a 1px horizontal container by default',
        (tester) async {
      await tester.pumpWidget(harness(f, const ClideDivider()));
      final c = tester.widget<Container>(find.byType(Container));
      expect(c.constraints?.maxHeight, 1.0);
      expect(c.color, f.services.theme.current.surface.dividerColor);
    });

    testWidgets('vertical axis yields a width-constrained container',
        (tester) async {
      await tester.pumpWidget(
        harness(f, const ClideDivider(axis: Axis.vertical, thickness: 2)),
      );
      final c = tester.widget<Container>(find.byType(Container));
      expect(c.constraints?.maxWidth, 2.0);
    });
  });
}
