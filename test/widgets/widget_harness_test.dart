/// Guards the shared widget harnesses themselves (T-572): a second
/// `pumpWidget` with a different child must reach the screen, not leave the
/// first child mounted behind an Overlay that only read its entries once.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  testWidgets('harness() shows the child of a re-pump', (tester) async {
    await tester.pumpWidget(harness(f, const Text('first')));
    expect(find.text('first'), findsOneWidget);

    await tester.pumpWidget(harness(f, const Text('second')));
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });

  testWidgets('anchoredHarness() shows the child of a re-pump', (tester) async {
    await tester.pumpWidget(anchoredHarness(f, const Text('first')));
    expect(find.text('first'), findsOneWidget);

    await tester.pumpWidget(anchoredHarness(f, const Text('second'), alignment: Alignment.center));
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
    expect(tester.getCenter(find.text('second')), const Offset(400, 300), reason: 'the new alignment applies too');
  });

  testWidgets('a re-pump keeps the child state when the child is the same type', (tester) async {
    await tester.pumpWidget(harness(f, const _Counter(label: 'a')));
    tester.state<_CounterState>(find.byType(_Counter)).bump();
    await tester.pumpWidget(harness(f, const _Counter(label: 'b')));
    expect(find.text('b 1'), findsOneWidget, reason: 'the entry rebuilds its child in place, not a fresh mount');
  });
}

class _Counter extends StatefulWidget {
  const _Counter({required this.label});

  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _n = 0;

  void bump() => _n++;

  @override
  Widget build(BuildContext context) => Text('${widget.label} $_n');
}
