import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kernel_fixture.dart';

/// Wraps a widget in the minimum tree a primitive needs to resolve
/// theme + i18n + Overlay (for Draggable feedback / Tooltip / etc.):
/// `Directionality → ClideKernel → ClideTheme → MediaQuery →
/// Overlay → child`.
///
/// The Overlay is sized by the test view's bounds via the surrounding
/// MediaQuery; no extra SizedBox is added so existing tests that
/// query `find.byType(SizedBox).first` still find their target.
Widget harness(KernelFixture fixture, Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: fixture.services,
      child: ClideTheme(
        controller: fixture.services.theme,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                canSizeOverlay: true,
                builder: (_) => child,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Harness for **anchored-overlay content** (ClideAnchoredOverlay popovers).
///
/// The shared [harness] wraps its child in `Overlay(canSizeOverlay)` + a
/// zero-size `MediaQuery` — fine for plain widgets, but it mispositions an
/// anchored follower off-screen and defeats `autoFlip`, so popover items aren't
/// reliably hit-testable. This builds a properly-sized Overlay tree instead:
/// `Directionality → ClideKernel → ClideTheme → MediaQuery(size) → Overlay`,
/// with [child] (the trigger) placed at [alignment]. Set
/// `tester.view.physicalSize = size` to match (the default 800×600 matches the
/// default test view, so no setup is needed unless you change [size]).
Widget anchoredHarness(
  KernelFixture fixture,
  Widget child, {
  Size size = const Size(800, 600),
  Alignment alignment = Alignment.topLeft,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: fixture.services,
      child: ClideTheme(
        controller: fixture.services.theme,
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: Overlay(
            initialEntries: [
              OverlayEntry(builder: (_) => Align(alignment: alignment, child: child)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Settle async-driven UI in a widget test WITHOUT the two patterns that have
/// repeatedly wedged this suite:
///
/// - **Never `pumpAndSettle()`** — it loops until the frame queue is quiescent,
///   so a perpetual animation or overlapping async loads hang it for its
///   ~10-minute default timeout (which wedged the pre-push gate).
/// - **Never `await Future.delayed(Duration.zero)`** — inside the fake-async
///   `testWidgets` zone a real timer never fires unless fake time is advanced,
///   so that line wedges the test until timeout (and even defeats `--timeout`).
///
/// Instead: pump one frame (draining the microtask queue — broadcast-stream and
/// async-IPC deliveries resolve here), then advance a tiny fake-time tick to
/// flush any follow-up `setState`. Bounded by construction — it cannot hang.
/// Use this after publishing a message / triggering a load in a reader/panel
/// widget test, in place of `pumpAndSettle`.
Future<void> pumpAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}
