import 'dart:io';

import 'package:clide/app.dart';
import 'package:clide/builtin/default_layout/default_layout.dart';
import 'package:clide/builtin/theme_picker/theme_picker.dart';
import 'package:clide/builtin/welcome/welcome.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fake_ipc.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('theme.pick command opens modal; selecting dismisses it', (tester) async {
    final themes = [await const ThemeLoader().fromAsset(rootBundle, 'lib/kernel/src/theme/themes/summer-night.yaml')];
    final services = await KernelServices.boot(
      appDir: await Directory.systemTemp.createTemp('clide_theme_intg_'),
      bundledThemes: themes,
      i18nLoader: AssetCatalogLoader(bundle: rootBundle),
      preloadNamespaces: const ['builtin.welcome', 'builtin.theme-picker', 'builtin.default-layout'],
      daemonClientFactory: (log, events, _, _) => FakeDaemonClient(log: log, events: events),
      autoStartDaemonClient: false,
    );
    services.extensions
      ..register(DefaultLayoutExtension())
      ..register(WelcomeExtension())
      ..register(ThemePickerExtension());
    await services.extensions.activateAll();

    // Larger viewport so the welcome screen's _StatusLine row doesn't
    // overflow on the default ~800x600 — that overflow throws a layout
    // assertion that fails the test before we get to theme.pick.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ClideApp(services: services));
    await tester.pumpAndSettle();

    // Fire-and-forget: theme.pick's run handler awaits
    // ctx.dialog.show(...), whose Future doesn't complete until the
    // dialog is dismissed. Awaiting here would deadlock the test
    // before the dialog ever mounts.
    final pending = services.commands.execute('theme.pick');
    await tester.pumpAndSettle();

    expect(find.text('Select theme'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Dismiss via Cancel — this completes the pending future above.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Select theme'), findsNothing);
    await pending;

    // Tear the widget tree down BEFORE disposing services so widgets
    // that listen to kernel notifiers (KeymapService, etc.) unsubscribe
    // first. Disposing services while the tree is mounted triggers
    // "ChangeNotifier used after dispose" during teardown rebuilds.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await services.dispose();
  });
}
