import 'package:clide/builtin/claude/src/turn_signals.dart';
import 'package:clide/builtin/clide_companion/src/companion_usage_line.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

/// T-556 — the stat that makes D-107's sharpest risk visible.
///
/// The numbers below are the measured ones (spike §9, two Haiku turns in one
/// session), because the phrasing has to survive real values: a total that is
/// almost all cache reads, and an output that is almost all thinking.
const _measured = TurnUsage(inputTokens: 20, outputTokens: 147, cacheCreationTokens: 16586, cacheReadTokens: 54482, thinkingTokens: 133, costUsd: 0.0393752);

/// The English catalog, inlined so the formatter can be exercised without a
/// loaded i18n asset.
String _en(String key, String value) => const {
  'usage.turns': '{n} turns',
  'usage.tokens': '{n} tokens',
  'usage.equivalent': '≈{n} equivalent',
  'usage.cacheRead': '{n} cache read',
  'usage.cacheWrite': '{n} cache write',
  'usage.spoken': '{n} spoken',
  'usage.thinking': '{n} thinking',
}[key]!.replaceAll('{n}', value);

void main() {
  group('what it says', () {
    test('the headline is how many, how much, and what it is worth', () {
      final lines = formatCompanionUsage(total: _measured, turns: 2, t: _en);
      expect(lines.headline, '2 turns  ·  71k tokens  ·  ≈\$0.04 equivalent');
    });

    test('the split is there because the total alone would mislead', () {
      // 54k of the 71k is cache reads — roughly a tenth the price of fresh
      // input. A reader seeing only "71k tokens" would over-estimate this by
      // most of an order of magnitude.
      final lines = formatCompanionUsage(total: _measured, turns: 2, t: _en);
      expect(lines.split, '54k cache read  ·  17k cache write  ·  14 spoken  ·  133 thinking');
    });

    test('thinking is called out against what he actually said', () {
      // The argument this surface exists to let someone make: he spent 133
      // tokens thinking to say 14. Both numbers have to be present for that to
      // be readable at all.
      final lines = formatCompanionUsage(total: _measured, turns: 2, t: _en);
      expect(lines.split, contains('14 spoken'));
      expect(lines.split, contains('133 thinking'));
    });

    test('the money is an equivalent, never a bill', () {
      // Under subscription auth nothing is charged — the currency is quota, and
      // upstream exposes no figure for it at all. A bare dollar amount would be
      // read as an invoice.
      final lines = formatCompanionUsage(total: _measured, turns: 2, t: _en);
      expect(lines.headline, contains('equivalent'));
      expect(lines.headline, isNot(contains('billed')));
      expect(lines.headline, isNot(contains('charged')));
    });
  });

  group('the surface', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    Widget host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: ClideKernel(
        services: f.services,
        child: ClideTheme(
          controller: f.services.theme,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 640, child: child),
          ),
        ),
      ),
    );

    testWidgets('renders both lines once he has spent anything', (tester) async {
      await tester.pumpWidget(host(const CompanionUsageLine(total: _measured, turns: 2)));
      expect(find.textContaining('2 turns'), findsOneWidget);
      expect(find.textContaining('71k tokens'), findsOneWidget);
      expect(find.textContaining('133 thinking'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('draws nothing before the first turn', (tester) async {
      // A row of zeros reads as a broken instrument rather than an idle one.
      await tester.pumpWidget(host(const CompanionUsageLine(total: TurnUsage(), turns: 0)));
      expect(find.byType(ClideText), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the caveat is readable, and pulled rather than announced', (tester) async {
      // D-20: a running total announcing itself through a live region would
      // interrupt a screen-reader user mid-output, which is the failure T-567
      // avoided for his remarks. It is available on request instead.
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(const CompanionUsageLine(total: _measured, turns: 2)));

      expect(find.bySemanticsLabel(RegExp('nothing is billed')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('133 thinking')), findsOneWidget);

      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
