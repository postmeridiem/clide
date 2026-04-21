import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ClideTabBar', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('renders one tab per item', (tester) async {
      await tester.pumpWidget(
        harness(
          f,
          ClideTabBar(
            items: const [
              ClideTabItem(id: 'a', title: 'A'),
              ClideTabItem(id: 'b', title: 'B'),
            ],
            activeId: 'a',
            onSelect: (_) {},
          ),
        ),
      );
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('tapping a tab fires onSelect with the id', (tester) async {
      String? selected;
      await tester.pumpWidget(
        harness(
          f,
          ClideTabBar(
            items: const [
              ClideTabItem(id: 'a', title: 'A'),
              ClideTabItem(id: 'b', title: 'B'),
            ],
            activeId: 'a',
            onSelect: (id) => selected = id,
          ),
        ),
      );
      await tester.tap(find.text('B'));
      expect(selected, 'b');
    });

    testWidgets('each tab is a selectable Semantics button', (tester) async {
      await tester.pumpWidget(
        harness(
          f,
          ClideTabBar(
            items: const [
              ClideTabItem(id: 'a', title: 'Files'),
              ClideTabItem(id: 'b', title: 'Git'),
            ],
            activeId: 'a',
            onSelect: (_) {},
          ),
        ),
      );
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Files')),
        matchesSemantics(
          label: 'Files',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Git')),
        matchesSemantics(
          label: 'Git',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
