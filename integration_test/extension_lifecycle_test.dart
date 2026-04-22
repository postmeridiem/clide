import 'dart:io';

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

  testWidgets('disable + re-enable an extension mounts/unmounts its UI',
      (tester) async {
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
      daemonClientFactory: (log, events) =>
          FakeDaemonClient(log: log, events: events),
      autoStartDaemonClient: false,
    );
    services.extensions
      ..register(DefaultLayoutExtension())
      ..register(WelcomeExtension())
      ..register(IpcStatusExtension());
    await services.extensions.activateAll();

    await tester.pumpWidget(ClideApp(services: services));
    await tester.pumpAndSettle();
    expect(find.text('disconnected'), findsOneWidget);

    // Disable ipc-status; status item should disappear.
    await services.extensions.setEnabled('builtin.ipc-status', false);
    await tester.pumpAndSettle();
    expect(find.text('disconnected'), findsNothing);

    // Re-enable; status item reappears.
    await services.extensions.setEnabled('builtin.ipc-status', true);
    await tester.pumpAndSettle();
    expect(find.text('disconnected'), findsOneWidget);

    await services.dispose();
  });
}
