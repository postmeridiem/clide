import 'dart:async';
import 'dart:io';

import 'package:clide/kernel/src/clipboard.dart';
import 'package:clide/kernel/src/commands/keybindings.dart';
import 'package:clide/kernel/src/keymap/keymap_service.dart';
import 'package:clide/kernel/src/text_zoom.dart';
import 'package:clide/kernel/src/theme/theme_persistence.dart';
import 'package:clide/kernel/src/toast.dart';
import 'package:clide/kernel/src/commands/palette.dart';
import 'package:clide/kernel/src/commands/registry.dart';
import 'package:clide/kernel/src/dialog.dart';
import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/filter_state.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/extensions_manager.dart';
import 'package:clide/kernel/src/files.dart';
import 'package:clide/kernel/src/focus.dart';
import 'package:clide/kernel/src/i18n/catalog_loader.dart';
import 'package:clide/kernel/src/i18n/i18n.dart';
import 'package:clide/kernel/src/ipc/client.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/log_ring.dart';
import 'package:clide/kernel/src/net.dart';
import 'package:clide/kernel/src/notify.dart';
import 'package:clide/kernel/src/os.dart';
import 'package:clide/kernel/src/panels/arrangement.dart';
import 'package:clide/kernel/src/panels/registry.dart';
import 'package:clide/kernel/src/project.dart';
import 'package:clide/kernel/src/quick_open.dart';
import 'package:clide/kernel/src/reader_nav.dart';
import 'package:clide/kernel/src/recent_files.dart';
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
    required this.filterStates,
    required this.ipc,
    required this.theme,
    required this.i18n,
    required this.panels,
    required this.arrangement,
    required this.commands,
    required this.palette,
    required this.quickOpen,
    required this.recentFiles,
    required this.readerNav,
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
    required this.keymap,
    required this.textZoom,
    required this.toast,
    required this.logRing,
  });

  final Logger log;
  final SettingsStore settings;
  final DaemonBus events;
  final MessageBus messages;

  /// Latest filter value per addressable box, fed by `filter.state`
  /// messages — backs the observe-half of `clide ui filter` (T-270).
  final FilterStateCache filterStates;
  final DaemonClient ipc;
  final ThemeController theme;
  final I18n i18n;
  final PanelRegistry panels;
  final LayoutArrangement arrangement;
  final CommandRegistry commands;
  final PaletteController palette;
  final QuickOpenController quickOpen;
  final RecentFilesService recentFiles;
  final ReaderNavRegistry readerNav;
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
  final KeymapService keymap;
  final TextZoom textZoom;
  final ToastService toast;

  /// Bounded retention of [log] records, for the output dock (T-54 / D-87).
  final LogRing logRing;

  static Future<KernelServices> boot({
    required Directory appDir,
    required List<ThemeDefinition> bundledThemes,
    required CatalogLoader i18nLoader,
    List<String> preloadNamespaces = const [],
    Locale defaultLocale = const Locale('en', 'US'),
    Locale? initialLocale,
    List<Locale> availableLocales = const [Locale('en', 'US')],
    String? socketPath,
    DaemonClient Function(Logger, DaemonBus, LayoutArrangement, PanelRegistry)? daemonClientFactory,
    DaemonClient? isolateClient,
    bool autoStartDaemonClient = true,
    Toolchain? toolchain,
    Future<void> Function(String path)? onProjectOpen,
    Future<String?> Function(String path)? onValidateProject,
    DaemonBus? sharedBus,
  }) async {
    final logRing = LogRing();
    final log = Logger(sinks: [stderrSink, logRing.add]);
    final events = sharedBus ?? DaemonBus();
    final messages = MessageBus();
    final filterStates = FilterStateCache(messages: messages);

    final settings = SettingsStore(appDir: appDir);
    await settings.load();

    final i18n = I18n(loader: i18nLoader, log: log, defaultLocale: defaultLocale, initialLocale: initialLocale, availableLocales: availableLocales);
    for (final ns in preloadNamespaces) {
      await i18n.ensureNamespaceLoaded(ns);
    }

    final theme = ThemeController(bundled: bundledThemes);
    wireThemePersistence(theme, settings);
    final panels = PanelRegistry();
    final arrangement = LayoutArrangement();
    final commands = CommandRegistry();
    final keybindings = KeybindingResolver();
    final keymap = KeymapService(settings: settings, appDir: appDir);
    await keymap.load();
    final palette = PaletteController(commands);
    final recentFiles = RecentFilesService();
    final quickOpen = QuickOpenController(recentPaths: () => recentFiles.paths);
    final readerNav = ReaderNavRegistry(messages);
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
    final textZoom = TextZoom();
    final toast = ToastService(messages: messages);
    final project = ProjectManager(
      log: log,
      events: events,
      settings: settings,
      toolchain: tc,
      onProjectOpen: onProjectOpen,
      onValidateProject: onValidateProject,
    );
    final ipc =
        isolateClient ??
        (daemonClientFactory != null
            ? daemonClientFactory(log, events, arrangement, panels)
            : DaemonClient(
                // Legacy socket-client fallback — kept until T-127
                // replaces it with the in-process socket loopback.
                // Today nothing in production hits this branch
                // (main.dart and the test harness pass an explicit
                // daemonClientFactory). If a caller does land here
                // without `autoStartDaemonClient: false`, the
                // placeholder path makes the failure mode obvious.
                socketPath: socketPath ?? '/dev/null/clide-legacy.sock',
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
      readerNav: readerNav,
      keybindings: keybindings,
      keymap: keymap,
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
      logRing: logRing,
      settings: settings,
      events: events,
      messages: messages,
      filterStates: filterStates,
      ipc: ipc,
      theme: theme,
      i18n: i18n,
      panels: panels,
      arrangement: arrangement,
      commands: commands,
      palette: palette,
      quickOpen: quickOpen,
      recentFiles: recentFiles,
      readerNav: readerNav,
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
      keymap: keymap,
      textZoom: textZoom,
      toast: toast,
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
    quickOpen.dispose();
    toast.dispose();
    recentFiles.dispose();
    readerNav.dispose();
    i18n.dispose();
    notify.dispose();
    dialog.dispose();
    tray.dispose();
    net.dispose();
    focus.dispose();
    project.dispose();
    extensions.dispose();
    await scheduler.dispose();
    keymap.dispose();
    textZoom.dispose();
    await log.dispose();
    filterStates.dispose();
    messages.dispose();
    await events.dispose();
  }
}

class ClideKernel extends InheritedWidget {
  const ClideKernel({super.key, required this.services, required super.child});

  final KernelServices services;

  static KernelServices of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<ClideKernel>();
    if (w == null) {
      throw FlutterError('ClideKernel.of() called with a context that is not a descendant of a ClideKernel.');
    }
    return w.services;
  }

  @override
  bool updateShouldNotify(ClideKernel oldWidget) => services != oldWidget.services;
}
