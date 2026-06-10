/// Tests for ClideSpinner + ClideStatusIndicator (T-296): the run-status glyph
/// (spinner / check / cross) and its reduced-motion behaviour.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  // Disable animations so the spinner is static (no perpetual rotation) and
  // pumpAndSettle can settle — mirroring how every animated widget behaves
  // under reduced motion.
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(harness(
        f,
        Builder(
          builder: (ctx) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
            child: Center(child: child),
          ),
        ),
      ));

  Finder iconWith(Object painterType) => find.byWidgetPredicate((w) => w is ClideIcon && w.painter.runtimeType == painterType);

  group('ClideSpinner', () {
    testWidgets('renders the logo mark and settles under reduced motion', (tester) async {
      await pump(tester, const ClideSpinner(size: 16));
      await tester.pumpAndSettle(); // would hang if it kept rotating
      expect(find.byType(ClideSvgView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ClideStatusIndicator', () {
    testWidgets('running shows the spinner', (tester) async {
      await pump(tester, const ClideStatusIndicator(status: ClideRunStatus.running));
      await tester.pumpAndSettle();
      expect(find.byType(ClideSpinner), findsOneWidget);
    });

    testWidgets('success shows a check', (tester) async {
      await pump(tester, const ClideStatusIndicator(status: ClideRunStatus.success));
      await tester.pumpAndSettle();
      expect(iconWith(CheckIcon), findsOneWidget);
      expect(find.byType(ClideSpinner), findsNothing);
    });

    testWidgets('error shows a cross', (tester) async {
      await pump(tester, const ClideStatusIndicator(status: ClideRunStatus.error));
      await tester.pumpAndSettle();
      expect(iconWith(CloseIcon), findsOneWidget);
    });

    testWidgets('rapid status flips within the cross-fade do not collide (T-326)', (tester) async {
      // Real animations (no disableAnimations) so the 200ms cross-fade overlaps
      // exiting and entering glyphs — the condition that tripped a duplicate
      // 'running' key. Pre-fix this threw "Duplicate keys found".
      var status = ClideRunStatus.running;
      late StateSetter set;
      await tester.pumpWidget(harness(
        f,
        Center(
          child: StatefulBuilder(builder: (ctx, s) {
            set = s;
            return ClideStatusIndicator(status: status);
          }),
        ),
      ));

      void flip(ClideRunStatus next) => set(() => status = next);

      flip(ClideRunStatus.success);
      await tester.pump(const Duration(milliseconds: 40));
      flip(ClideRunStatus.running); // a 2nd 'running' while the 1st is still exiting
      await tester.pump(const Duration(milliseconds: 40));
      flip(ClideRunStatus.error);
      await tester.pump(const Duration(milliseconds: 40));
      flip(ClideRunStatus.success); // land on a static glyph
      await tester.pump(const Duration(milliseconds: 40));

      expect(tester.takeException(), isNull);
      // Unmount so any in-flight spinner controller disposes (no pending timers).
      await tester.pumpWidget(const SizedBox());
    });
  });
}
