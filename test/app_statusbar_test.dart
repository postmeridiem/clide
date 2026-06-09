/// Regression test for the bottom status bar's right-group alignment (T-239):
/// within the center (workspace) bar, left items are start-aligned and the
/// right group (tool status / theme switcher) hugs the right edge — even with
/// a flex left item present, and at ANY bar width incl. ultrawide (where the
/// old Spacer-vs-flex layout drifted noticeably). Uses the REAL StatusbarHost
/// with real StatusItemContributions; the surface is sized per case via
/// tester.view so a wide SizedBox isn't clamped to the default 800px surface.
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
            data: MediaQueryData(size: Size(width, 200)),
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
  tearDown(() async {
    await f.dispose();
  });

  Future<void> pumpAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(_bar(f, width));
    await tester.pump();
  }

  testWidgets('right group hugs the bar right edge at normal AND ultrawide widths (T-239)', (tester) async {
    // Mirrors the real surface: a left flex:1 item (like the Claude status
    // marquee, priority 50) + a right-group item (priority >= 100).
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

    // 600 = normal, 3440 = ultrawide (where the float actually surfaced).
    for (final width in [600.0, 3440.0]) {
      await pumpAt(tester, width);
      expect(tester.takeException(), isNull, reason: 'width=$width');
      // StatusbarHost pads 4px each side and reserves a fixed 24px collapse-
      // toggle cell at each end (T-294), so status items sit 28px inside both
      // edges: right item's right edge ≈ width - 28, left item's left ≈ 28.
      expect(tester.getTopRight(find.text('RIGHT')).dx, closeTo(width - 28, 1.0), reason: 'right group not at edge at width=$width');
      expect(tester.getTopLeft(find.text('LEFT')).dx, closeTo(28, 1.0), reason: 'left not at start at width=$width');
    }
  });

  testWidgets('right group hugs the edge with no left items (ultrawide)', (tester) async {
    f.services.panels.contribute(StatusItemContribution(
      id: 'test.right.only',
      priority: 110,
      build: (_) => const Text('R2', softWrap: false),
    ));
    await pumpAt(tester, 3440.0);
    expect(tester.takeException(), isNull);
    // 4px pad + 24px reserved toggle cell at the right end (T-294).
    expect(tester.getTopRight(find.text('R2')).dx, closeTo(3440 - 28, 1.0));
  });
}
