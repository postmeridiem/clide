import 'dart:io';
import 'dart:ui';

import 'package:clide/app.dart';
import 'package:clide/builtin/default_layout/default_layout.dart';
import 'package:clide/builtin/ipc_status/ipc_status.dart';
import 'package:clide/builtin/welcome/welcome.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fake_ipc.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('disable + re-enable an extension mounts/unmounts its UI', (tester) async {
    // Welcome view overflows the default headless viewport — give it a
    // desktop-sized window so layout is representative.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final themes = [
      await const ThemeLoader().fromAsset(
        rootBundle,
        'lib/kernel/src/theme/themes/summer-night.yaml',
      ),
    ];
    final services = await KernelServices.boot(
      appDir: await Directory.systemTemp.createTemp('clide_lc_'),
      bundledThemes: themes,
      i18nLoader: AssetCatalogLoader(bundle: rootBundle),
      preloadNamespaces: const [
        'builtin.welcome',
        'builtin.ipc-status',
        'builtin.default-layout',
      ],
      daemonClientFactory: (log, events, _, __) => FakeDaemonClient(log: log, events: events),
      autoStartDaemonClient: false,
    );
    services.extensions
      ..register(DefaultLayoutExtension())
      ..register(WelcomeExtension())
      ..register(IpcStatusExtension());
    await services.extensions.activateAll();

    await tester.pumpWidget(ClideApp(services: services));
    await tester.pumpAndSettle();
    // The ipc-status extension contributes a ToolStatusItem to the
    // statusbar; we assert its presence by widget type so the test
    // doesn't depend on whichever status string (`application ok` /
    // `checking…` / `<tool> not found`) the toolchain happens to be in.
    expect(find.byType(ToolStatusItem), findsOneWidget);

    // Disable ipc-status; status item should disappear.
    await services.extensions.setEnabled('builtin.ipc-status', false);
    await tester.pumpAndSettle();
    expect(find.byType(ToolStatusItem), findsNothing);

    // Re-enable; status item reappears.
    await services.extensions.setEnabled('builtin.ipc-status', true);
    await tester.pumpAndSettle();
    expect(find.byType(ToolStatusItem), findsOneWidget);

    await services.dispose();
  });
}
