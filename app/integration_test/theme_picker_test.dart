import 'dart:io';

import 'package:clide_app/app.dart';
import 'package:clide_app/builtin/default_layout/default_layout.dart';
import 'package:clide_app/builtin/theme_picker/theme_picker.dart';
import 'package:clide_app/builtin/welcome/welcome.dart';
import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fake_ipc.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('theme.pick command opens modal; selecting dismisses it',
      (tester) async {
    final themes = [
      await const ThemeLoader().fromAsset(
        rootBundle,
        'lib/kernel/src/theme/themes/summer-night.yaml',
      ),
    ];
    final services = await KernelServices.boot(
      appDir: await Directory.systemTemp.createTemp('clide_theme_intg_'),
      bundledThemes: themes,
      i18nLoader: AssetCatalogLoader(bundle: rootBundle),
      preloadNamespaces: const [
        'builtin.welcome',
        'builtin.theme-picker',
        'builtin.default-layout',
      ],
      daemonClientFactory: (log, events) =>
          FakeDaemonClient(log: log, events: events),
      autoStartDaemonClient: false,
    );
    services.extensions
      ..register(DefaultLayoutExtension())
      ..register(WelcomeExtension())
      ..register(ThemePickerExtension());
    await services.extensions.activateAll();

    await tester.pumpWidget(ClideApp(services: services));
    await tester.pumpAndSettle();

    // Invoke the command.
    await services.commands.execute('theme.pick');
    await tester.pumpAndSettle();

    expect(find.text('Select theme'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Dismiss via Cancel.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Select theme'), findsNothing);

    await services.dispose();
  });
}
