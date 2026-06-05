/// Regression test for the bottom status bar's right-group alignment (T-239):
/// within the center (workspace) bar, left items are start-aligned and the
/// right group (tool status / theme switcher) hugs the right edge — even with
/// a flex left item present, and at any bar width. Uses the REAL StatusbarHost
/// with real StatusItemContributions, in a tight SizedBox (not the shared
/// harness, which hands unbounded width — see pane_context_status_test).
library;

import 'package:clide/app.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/kernel_fixture.dart';

Widget _bar(KernelFixture f, double width) => Directionality(
      textDirection: TextDirection.ltr,
      child: ClideKernel(
        services: f.services,
        child: ClideTheme(
          controller: f.services.theme,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, height: 26, child: const StatusbarHost()),
            ),
          ),
        ),
      ),
    );

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  testWidgets('right group hugs the bar right edge; a flex left item does not push it (T-239)', (tester) async {
    // Mirrors the real surface: a left flex:1 item (like the Claude status
    // marquee, priority 50) + right-group items (priority >= 100).
    f.services.panels.contribute(StatusItemContribution(
      id: 'test.left.flex',
      priority: 50,
      flex: 1,
      build: (_) => const Text('LEFT', softWrap: false),
    ));
    f.services.panels.contribute(StatusItemContribution(
      id: 'test.right',
      priority: 110,
      build: (_) => const Text('RIGHT', softWrap: false),
    ));

    const width = 600.0;
    await tester.pumpWidget(_bar(f, width));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // StatusbarHost pads 8px each side → the right item's right edge sits at
    // width - 8. If the right group floated mid-bar this would be well short.
    expect(tester.getTopRight(find.text('RIGHT')).dx, closeTo(width - 8, 1.0));
    // And the left item starts at the left (8px pad).
    expect(tester.getTopLeft(find.text('LEFT')).dx, closeTo(8, 1.0));
  });

  testWidgets('right group still hugs the edge with no left items', (tester) async {
    f.services.panels.contribute(StatusItemContribution(
      id: 'test.right.only',
      priority: 110,
      build: (_) => const Text('R2', softWrap: false),
    ));
    const width = 500.0;
    await tester.pumpWidget(_bar(f, width));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getTopRight(find.text('R2')).dx, closeTo(width - 8, 1.0));
  });
}
