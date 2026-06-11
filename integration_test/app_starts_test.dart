import 'dart:io';
import 'dart:ui';

import 'package:clide/app.dart';
import 'package:clide/builtin/default_layout/default_layout.dart';
import 'package:clide/builtin/ipc_status/ipc_status.dart';
import 'package:clide/builtin/theme_picker/theme_picker.dart';
import 'package:clide/builtin/welcome/welcome.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fake_ipc.dart';

/// The load-bearing startup gate.
///
/// Tests the *real* `ClideApp` boot path with real bindings (not a
/// mocked-up widget tree). Catches the class of regressions a widget
/// test can't see: initialization-order bugs, asset-not-bundled,
/// plugin-init failures, notifier-leak-on-boot.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clide app boots with classic 3-column layout + welcome + statusbar', (tester) async {
    // The welcome view's TIPS card overflows the default headless test
    // viewport (~800px); give it a desktop-sized window so layout is
    // representative of a real launch.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final themes = [await const ThemeLoader().fromAsset(rootBundle, 'lib/kernel/src/theme/themes/summer-night.yaml')];
    final services = await KernelServices.boot(
      appDir: await Directory.systemTemp.createTemp('clide_intg_'),
      bundledThemes: themes,
      i18nLoader: AssetCatalogLoader(bundle: rootBundle),
      preloadNamespaces: const ['builtin.welcome', 'builtin.ipc-status', 'builtin.theme-picker', 'builtin.default-layout'],
      daemonClientFactory: (log, events, _, _) => FakeDaemonClient(log: log, events: events),
      autoStartDaemonClient: false,
    );
    services.extensions
      ..register(DefaultLayoutExtension())
      ..register(WelcomeExtension())
      ..register(IpcStatusExtension())
      ..register(ThemePickerExtension());
    await services.extensions.activateAll();

    await tester.pumpWidget(ClideApp(services: services));
    await tester.pumpAndSettle();

    // Shell — three columns and a statusbar all materialize.
    expect(find.byType(RootLayout), findsOneWidget);
    expect(find.byType(SlotHost), findsWidgets);
    expect(find.byType(StatusbarHost), findsOneWidget);

    // Welcome tab is mounted in the workspace.
    expect(find.text('clide'), findsWidgets);
    // The visible START row exposes "Open folder…"; the "Open project"
    // dialog title only appears after the user clicks through, so we
    // assert the on-boot label here.
    expect(find.text('Open folder…'), findsWidgets);

    // Welcome view's toolchain status shows "checking…" while the
    // backend hasn't reported resolution (FakeDaemonClient never does
    // — autoStartDaemonClient is false).
    expect(find.text('checking…'), findsWidgets);

    await services.dispose();
  });
}
