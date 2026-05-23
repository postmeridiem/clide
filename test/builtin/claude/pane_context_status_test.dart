/// Tests for the status-bar in-pane context slot (T-145): it shows the
/// latest text published on the bus channel and clears on empty.
library;

import 'package:clide/builtin/claude/src/pane_context_status.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  testWidgets('renders the latest published context, clears on empty', (tester) async {
    await tester.pumpWidget(harness(f, const PaneContextStatusItem()));
    await tester.pump();
    expect(find.byType(ClideText), findsNothing); // nothing published yet

    publishPaneContext(f.services.messages, 'builtin.claude', 'opus 4.7  ·  default  ·  21k ctx');
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('opus 4.7'), findsOneWidget);

    // A newer publisher overwrites the slot.
    publishPaneContext(f.services.messages, 'builtin.editor', 'lib/app.dart  ·  modified');
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('opus 4.7'), findsNothing);
    expect(find.textContaining('lib/app.dart'), findsOneWidget);

    // Empty clears it.
    publishPaneContext(f.services.messages, 'builtin.editor', '');
    await tester.pump();
    await tester.pump();
    expect(find.byType(ClideText), findsNothing);
  });
}
