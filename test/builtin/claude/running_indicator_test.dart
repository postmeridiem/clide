/// T-255: RunningIndicator — animated ellipsis + rotating verb, reduced-motion
/// fallback. Driven off the AnimationController's value, so the test advances
/// it with bounded pumps (no real timers).
library;

import 'package:clide/builtin/claude/src/running_indicator.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

String? _text(WidgetTester t) {
  final w = t.widget<ClideText>(find.byType(ClideText));
  return w.data;
}

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  Widget wrap({bool reducedMotion = false}) => MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: const RunningIndicator(shuffle: false),
      );

  testWidgets('animates the ellipsis and rotates the verb', (tester) async {
    await tester.pumpWidget(harness(f, wrap()));
    await tester.pump();
    expect(_text(tester), 'Pondering'); // t≈0: first verb, no dots

    await tester.pump(const Duration(milliseconds: 1100));
    expect(_text(tester), 'Pondering.'); // ~1.1s → 1 dot

    await tester.pump(const Duration(milliseconds: 1100));
    expect(_text(tester), 'Pondering..'); // ~2.2s → 2 dots

    await tester.pump(const Duration(milliseconds: 2000));
    expect(_text(tester), 'Conjuring'); // ~4.2s → second verb, dots wrapped to 0

    // Dispose the infinite animation before the test ends.
    await tester.pumpWidget(harness(f, const SizedBox()));
  });

  testWidgets('reduced motion shows a static verb that does not change', (tester) async {
    await tester.pumpWidget(harness(f, wrap(reducedMotion: true)));
    await tester.pump();
    expect(_text(tester), 'Pondering…');
    await tester.pump(const Duration(seconds: 6));
    expect(_text(tester), 'Pondering…'); // unchanged — no animation running
  });

  testWidgets('shuffle:true renders a verb from the list', (tester) async {
    await tester.pumpWidget(harness(f, const MediaQuery(data: MediaQueryData(), child: RunningIndicator(shuffle: true))));
    await tester.pump();
    final word = _text(tester)!.replaceAll('.', '');
    expect(runningVerbs.contains(word), isTrue);
    await tester.pumpWidget(harness(f, const SizedBox())); // dispose the animation
  });
}
