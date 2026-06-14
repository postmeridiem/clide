/// App entry widget. The shell itself lives under `lib/src/shell/`
/// (T-394 split): keyboard routing in root_shell.dart, the hat bar +
/// project switcher, slot hosting, and the layout grid + status bar.
/// The public layout symbols are re-exported here so existing imports
/// of `package:clide/app.dart` keep working.
library;

import 'package:clide/clide.dart' show clideName;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/shell/root_shell.dart';
import 'package:flutter/widgets.dart';

export 'package:clide/src/shell/layout.dart' show RootLayout, StatusbarCollapseToggle, StatusbarHost;
export 'package:clide/src/shell/slot_host.dart' show SlotHost;

class ClideApp extends StatelessWidget {
  const ClideApp({super.key, required this.services});

  final KernelServices services;

  @override
  Widget build(BuildContext context) {
    return ClideKernel(
      services: services,
      child: ClideTheme(
        controller: services.theme,
        child: _AppRoot(services: services),
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot({required this.services});
  final KernelServices services;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      debugShowCheckedModeBanner: false,
      title: clideName,
      color: const Color(0xFF000000),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) => PageRouteBuilder<T>(settings: settings, pageBuilder: (ctx, _, _) => builder(ctx)),
      home: RootShell(services: services),
    );
  }
}
