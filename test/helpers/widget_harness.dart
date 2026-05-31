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
