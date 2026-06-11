/// Tests for ClidePane (T-150): it surfaces its statusWidget to the
/// FocusTracker slot only while it is the shown (focused + active) pane.
library;

import 'package:clide/builtin/claude/src/pane_context_status.dart';
import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  testWidgets('conveys its status while its contribution is focused, clears on blur', (tester) async {
    await tester.pumpWidget(
      harness(
        f,
        const ClidePane(
          contributionId: 'pane.x',
          statusWidget: Text('S', textDirection: TextDirection.ltr),
          child: SizedBox(),
        ),
      ),
    );
    final focus = f.services.focus;
    expect(focus.activeStatusWidget, isNull); // not focused yet

    focus.setActive(slot: Slots.workspace, contributionId: 'pane.x');
    await tester.pump();
    expect(focus.activeStatusWidget, isA<Text>());

    focus.setActive(slot: Slots.workspace, contributionId: 'other');
    await tester.pump();
    expect(focus.activeStatusWidget, isNull); // focus moved away → cleared
  });

  testWidgets('mounting while focused does not notify focus listeners during build', (tester) async {
    // Regression: ClidePane.didChangeDependencies runs during the build phase,
    // and conveying synchronously rebuilt the focus-listening status item
    // mid-build ("markNeedsBuild during build"). A focus listener must be in
    // the tree to reproduce it.
    f.services.focus.setActive(slot: Slots.workspace, contributionId: 'pane.x');
    await tester.pumpWidget(
      harness(
        f,
        const Column(
          children: [
            PaneContextStatusItem(),
            ClidePane(
              contributionId: 'pane.x',
              statusWidget: Text('S', textDirection: TextDirection.ltr),
              child: SizedBox(),
            ),
          ],
        ),
      ),
    );
    await tester.pump(); // run the deferred post-frame convey
    expect(tester.takeException(), isNull);
    expect(f.services.focus.activeStatusWidget, isA<Text>());
  });

  testWidgets('an inactive pane never conveys', (tester) async {
    await tester.pumpWidget(
      harness(
        f,
        const ClidePane(
          contributionId: 'pane.x',
          active: false,
          statusWidget: Text('S', textDirection: TextDirection.ltr),
          child: SizedBox(),
        ),
      ),
    );
    f.services.focus.setActive(slot: Slots.workspace, contributionId: 'pane.x');
    await tester.pump();
    expect(f.services.focus.activeStatusWidget, isNull);
  });

  testWidgets('re-conveys when statusWidget changes while focused', (tester) async {
    f.services.focus.setActive(slot: Slots.workspace, contributionId: 'pane.x');
    var label = 'A';
    late StateSetter setLabel;
    await tester.pumpWidget(
      harness(
        f,
        StatefulBuilder(
          builder: (ctx, setState) {
            setLabel = setState;
            return ClidePane(
              contributionId: 'pane.x',
              statusWidget: Text(label, textDirection: TextDirection.ltr),
              child: const SizedBox(),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect((f.services.focus.activeStatusWidget! as Text).data, 'A');

    setLabel(() => label = 'B');
    await tester.pump();
    expect((f.services.focus.activeStatusWidget! as Text).data, 'B');
  });
}
