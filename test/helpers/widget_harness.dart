import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';

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
              OverlayEntry(builder: (_) => child),
            ],
          ),
        ),
      ),
    ),
  );
}
