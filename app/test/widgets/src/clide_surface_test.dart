import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ClideSurface', () {
    late KernelFixture f;

    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('default background comes from panelBackground token',
        (tester) async {
      await tester.pumpWidget(
        harness(f, const ClideSurface(child: Text('x'))),
      );
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(
          decoration.color, f.services.theme.current.surface.panelBackground);
    });

    testWidgets('explicit color overrides the token default', (tester) async {
      const custom = Color(0xFF123456);
      await tester.pumpWidget(
        harness(f, const ClideSurface(color: custom, child: Text('x'))),
      );
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, custom);
    });

    testWidgets('border when provided renders a BoxBorder', (tester) async {
      await tester.pumpWidget(
        harness(
          f,
          ClideSurface(
            border: f.services.theme.current.surface.modalSurfaceBorder,
            child: const Text('x'),
          ),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });
  });
}
