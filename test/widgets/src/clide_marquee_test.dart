/// Tests for ClideMarquee (T-150): static when the child fits, scrolls
/// (looped copy) when it overflows; clips its box.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _boxed(double width, Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(width: width, height: 16, child: child),
      ),
    );

void main() {
  testWidgets('shows the child statically when it fits', (tester) async {
    await tester.pumpWidget(_boxed(300, const ClideMarquee(child: Text('short'))));
    await tester.pump();
    expect(find.text('short'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // tear down the ticker
  });

  testWidgets('renders a looped copy and runs without overflow when wider than the slot', (tester) async {
    await tester.pumpWidget(_boxed(40, const ClideMarquee(child: Text('a long status line that overflows the slot'))));
    await tester.pump(); // measure
    await tester.pump(const Duration(milliseconds: 100)); // advance the ticker
    expect(find.text('a long status line that overflows the slot'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox()); // dispose → stop ticker
  });
}
