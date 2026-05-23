/// Tests for the focus-driven status-bar slot item (T-150): it renders
/// the focused pane's status widget and clears when focus moves to a
/// pane with no status.
library;

import 'package:clide/builtin/claude/src/pane_context_status.dart';
import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  testWidgets('renders the focused pane status, clears on focus change', (tester) async {
    await tester.pumpWidget(harness(f, const PaneContextStatusItem()));
    await tester.pump();
    expect(find.text('S'), findsNothing); // nothing focused

    final focus = f.services.focus;
    focus.setActive(slot: Slots.workspace, contributionId: 'pane.x');
    focus.setStatusWidget('pane.x', const Text('S', textDirection: TextDirection.ltr));
    await tester.pump();
    expect(find.text('S'), findsOneWidget);

    // Focus a pane with no status → the slot clears.
    focus.setActive(slot: Slots.workspace, contributionId: 'pane.y');
    await tester.pump();
    expect(find.text('S'), findsNothing);
  });
}
