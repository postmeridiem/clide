/// Widget coverage for the "compacting context" strip (T-244): hidden when
/// idle, a spinner + label and a live-region announcement while compacting.
library;

import 'package:clide/builtin/claude/src/claude_compacting_indicator.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  Future<void> pump(WidgetTester tester, {required bool active}) async {
    await tester.pumpWidget(
      harness(
        f,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 400, child: ClaudeCompactingIndicator(active: active)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders nothing when not compacting', (tester) async {
    await pump(tester, active: false);
    expect(find.byType(ClideText), findsNothing);
    expect(find.byType(ClideSpinner), findsNothing);
  });

  testWidgets('shows a spinner and the label while compacting, as a live region', (tester) async {
    await pump(tester, active: true);
    expect(find.byType(ClideSpinner), findsOneWidget);
    expect(find.text('Compacting context…'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true && w.properties.label == 'Compacting context…'), findsOneWidget);
  });
}
