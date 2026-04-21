import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter/widgets.dart';

import 'kernel_fixture.dart';

/// Wraps a widget in the minimum tree a primitive needs to resolve
/// theme + i18n: `Directionality → ClideKernel → ClideTheme → child`.
Widget harness(KernelFixture fixture, Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: fixture.services,
      child: ClideTheme(
        controller: fixture.services.theme,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: child,
        ),
      ),
    ),
  );
}
