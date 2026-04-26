import 'dart:async';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/kernel/src/clipboard.dart';
import 'package:clide/kernel/src/commands/keybindings.dart';
import 'package:clide/kernel/src/commands/palette.dart';
import 'package:clide/kernel/src/commands/registry.dart';
import 'package:clide/kernel/src/dialog.dart';
import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/extensions_manager.dart';
import 'package:clide/kernel/src/files.dart';
import 'package:clide/kernel/src/focus.dart';
import 'package:clide/kernel/src/i18n/catalog_loader.dart';
import 'package:clide/kernel/src/i18n/i18n.dart';
import 'package:clide/kernel/src/ipc/client.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/net.dart';
import 'package:clide/kernel/src/notify.dart';
import 'package:clide/kernel/src/os.dart';
import 'package:clide/kernel/src/panels/arrangement.dart';
import 'package:clide/kernel/src/panels/registry.dart';
import 'package:clide/kernel/src/project.dart';
import 'package:clide/kernel/src/scheduler.dart';
import 'package:clide/kernel/src/secrets.dart';
import 'package:clide/kernel/src/settings.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/loader.dart';
import 'package:clide/kernel/src/toolchain.dart';
import 'package:clide/kernel/src/tray.dart';
import 'package:clide/kernel/src/window_controls.dart';
import 'package:flutter/widgets.dart';

/// Aggregated kernel services. Feature code that runs outside a
/// BuildContext (extensions, background tasks) holds a [KernelServices]
/// ref directly; widget code reaches them via [ClideKernel.of].
class KernelServices {
  KernelServices({
    required this.log,
    required this.settings,
    required this.events,
    required this.messages,
    required this.ipc,
    required this.theme,
    required this.i18n,
    required this.panels,
    required this.arrangement,
    required this.commands,
    required this.palette,
    required this.keybindings,
    required this.clipboard,
    required this.files,
    required this.notify,
    required this.dialog,
    required this.tray,
    required this.secrets,
    required this.os,
    required this.net,
    required this.focus,
    required this.project,
    required this.extensions,
    required this.window,
    required this.toolchain,
    required this.scheduler,
  });

  final Logger log;
  final SettingsStore settings;
  final DaemonBus events;
  final MessageBus messages;
  final DaemonClient ipc;
  final ThemeController theme;
  final I18n i18n;
  final PanelRegistry panels;
  final LayoutArrangement arrangement;
  final CommandRegistry commands;
  final PaletteController palette;
  final KeybindingResolver keybindings;
  final ClideClipboard clipboard;
  final FileServices files;
  final Notifications notify;
  final DialogRouter dialog;
  final TrayRegistry tray;
  final SecretsVault secrets;
  final OsBridge os;
  final NetworkStatus net;
  final FocusTracker focus;
  final ProjectManager project;
  final ExtensionManager extensions;
  final WindowControls window;
  final Toolchain toolchain;
  final SchedulerService scheduler;

  static Future<KernelServices> boot({
    required Directory appDir,
    required List<ThemeDefinition> bundledThemes,
    required CatalogLoader i18nLoader,
    List<String> preloadNamespaces = const [],
    Locale defaultLocale = const Locale('en', 'US'),
    Locale? initialLocale,
    List<Locale> availableLocales = const [Locale('en', 'US')],
    String? socketPath,
    DaemonClient Function(Logger, DaemonBus)? daemonClientFactory,
    DaemonClient? isolateClient,
    bool autoStartDaemonClient = true,
    Toolchain? toolchain,
    Future<void> Function(String path)? onProjectOpen,
    Future<String?> Function(String path)? onValidateProject,
  }) async {
    final log = Logger();
    final events = DaemonBus();
    final messages = MessageBus();

    final settings = SettingsStore(appDir: appDir);
    await settings.load();

    final i18n = I18n(
      loader: i18nLoader,
      log: log,
      defaultLocale: defaultLocale,
      initialLocale: initialLocale,
      availableLocales: availableLocales,
    );
    for (final ns in preloadNamespaces) {
      await i18n.ensureNamespaceLoaded(ns);
    }

    final theme = ThemeController(bundled: bundledThemes);
    final panels = PanelRegistry();
    final arrangement = LayoutArrangement();
    final commands = CommandRegistry();
    final keybindings = KeybindingResolver();
    final palette = PaletteController(commands);
    final clipboard = ClideClipboard();
    final files = FileServices(events);
    final notify = Notifications();
    final dialog = DialogRouter();
    final tray = TrayRegistry();
    final secrets = SecretsVault();
    final os = OsBridge(log: log, events: events);
    final net = NetworkStatus();
    final focus = FocusTracker();
    final window = WindowControls();
    final tc = toolchain ?? Toolchain();
    final scheduler = SchedulerService(events);
    scheduler.start();
    final project = ProjectManager(
      log: log,
      events: events,
      settings: settings,
      toolchain: tc,
      onProjectOpen: onProjectOpen,
      onValidateProject: onValidateProject,
    );
    final ipc = isolateClient
        ?? (daemonClientFactory != null
            ? daemonClientFactory(log, events)
            : DaemonClient(
                socketPath: socketPath ?? defaultSocketPath(),
                log: log,
                events: events,
              ));
    final extensions = ExtensionManager(
      log: log,
      events: events,
      messages: messages,
      settings: settings,
      theme: theme,
      i18n: i18n,
      panels: panels,
      arrangement: arrangement,
      commands: commands,
      palette: palette,
      keybindings: keybindings,
      clipboard: clipboard,
      files: files,
      notify: notify,
      dialog: dialog,
      tray: tray,
      secrets: secrets,
      os: os,
      net: net,
      focus: focus,
      project: project,
      ipc: ipc,
    );

    if (autoStartDaemonClient) {
      unawaited(ipc.start());
    }

    return KernelServices(
      log: log,
      settings: settings,
      events: events,
      messages: messages,
      ipc: ipc,
      theme: theme,
      i18n: i18n,
      panels: panels,
      arrangement: arrangement,
      commands: commands,
      palette: palette,
      keybindings: keybindings,
      clipboard: clipboard,
      files: files,
      notify: notify,
      dialog: dialog,
      tray: tray,
      secrets: secrets,
      os: os,
      net: net,
      focus: focus,
      project: project,
      extensions: extensions,
      window: window,
      toolchain: tc,
      scheduler: scheduler,
    );
  }

  Future<void> dispose() async {
    await ipc.stop();
    ipc.dispose();
    settings.dispose();
    theme.dispose();
    panels.dispose();
    arrangement.dispose();
    commands.dispose();
    palette.dispose();
    i18n.dispose();
    notify.dispose();
    dialog.dispose();
    tray.dispose();
    net.dispose();
    focus.dispose();
    project.dispose();
    extensions.dispose();
    scheduler.dispose();
    await log.dispose();
    messages.dispose();
    await events.dispose();
  }
}

class ClideKernel extends InheritedWidget {
  const ClideKernel({
    super.key,
    required this.services,
    required super.child,
  });

  final KernelServices services;

  static KernelServices of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<ClideKernel>();
    if (w == null) {
      throw FlutterError(
          'ClideKernel.of() called with a context that is not a descendant of a ClideKernel.');
    }
    return w.services;
  }

  @override
  bool updateShouldNotify(ClideKernel oldWidget) =>
      services != oldWidget.services;
}
