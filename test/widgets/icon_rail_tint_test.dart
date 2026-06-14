/// ClideIconRail identity tint (T-418): an item's iconColor overrides the
/// state colours — full-strength when active or hovered, dimmed when idle.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  const tint = Color(0xFFD97757);
  final items = [
    ClideIconRailItem(id: 'claude', icon: PhosphorIcons.byName('robot'), tooltip: 'Claude', iconColor: tint),
    ClideIconRailItem(id: 'files', icon: PhosphorIcons.byName('folder'), tooltip: 'Files'),
  ];

  Future<void> pump(WidgetTester tester, {required String activeId}) async {
    await tester.pumpWidget(
      harness(
        f,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 40,
            child: ClideIconRail(items: items, activeId: activeId, onSelect: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  ClideIcon iconFor(WidgetTester tester, String tooltip) =>
      tester.widget<ClideIcon>(find.descendant(of: find.bySemanticsLabel(tooltip), matching: find.byType(ClideIcon)));

  testWidgets('an active tinted item renders the tint full-strength', (tester) async {
    await pump(tester, activeId: 'claude');
    expect(iconFor(tester, 'Claude').color, tint);
  });

  testWidgets('an idle tinted item renders the tint dimmed, untinted items keep state colours', (tester) async {
    await pump(tester, activeId: 'files');
    final claude = iconFor(tester, 'Claude').color!;
    expect(claude.toARGB32() & 0x00FFFFFF, tint.toARGB32() & 0x00FFFFFF); // same hue
    expect(claude.a, lessThan(1.0)); // dimmed while idle
    expect(iconFor(tester, 'Files').color, isNot(tint)); // untinted untouched
  });
}
