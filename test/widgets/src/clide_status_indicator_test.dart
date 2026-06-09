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
  });
}
