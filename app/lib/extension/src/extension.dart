import 'package:clide_app/extension/src/contribution.dart';
import 'package:clide_app/kernel/src/clipboard.dart';
import 'package:clide_app/kernel/src/commands/palette.dart';
import 'package:clide_app/kernel/src/commands/registry.dart';
import 'package:clide_app/kernel/src/dialog.dart';
import 'package:clide_app/kernel/src/events/bus.dart';
import 'package:clide_app/kernel/src/files.dart';
import 'package:clide_app/kernel/src/focus.dart';
import 'package:clide_app/kernel/src/i18n/i18n.dart';
import 'package:clide_app/kernel/src/ipc/client.dart';
import 'package:clide_app/kernel/src/log.dart';
import 'package:clide_app/kernel/src/net.dart';
import 'package:clide_app/kernel/src/notify.dart';
import 'package:clide_app/kernel/src/os.dart';
import 'package:clide_app/kernel/src/panels/arrangement.dart';
import 'package:clide_app/kernel/src/panels/registry.dart';
import 'package:clide_app/kernel/src/project.dart';
import 'package:clide_app/kernel/src/secrets.dart';
import 'package:clide_app/kernel/src/settings.dart';
import 'package:clide_app/kernel/src/theme/controller.dart';
import 'package:clide_app/kernel/src/tray.dart';

/// One shipping unit. Built-in extensions compile in as Dart subclasses;
/// third-party extensions run as Lua scripts wrapped by a `LuaExtension`
/// adapter (Tier 6).
abstract class ClideExtension {
  String get id;
  String get title;
  String get version;

  /// IDs of other extensions that must be activated before this one.
  /// Missing deps → this extension is skipped at load with a warning.
  List<String> get dependsOn => const [];

  /// The atoms this extension contributes.
  List<ContributionPoint> get contributions;

  /// Called once after dependencies activate.
  Future<void> activate(ClideExtensionContext ctx) async {}

  /// Called when the extension is disabled or the app shuts down.
  Future<void> deactivate() async {}
}

/// Handed to every [ClideExtension.activate]. Lists every kernel service
/// an extension may reach. The extension manager constructs a concrete
/// instance with refs; tests can pass fakes.
///
/// The interface deliberately lists services individually rather than
/// exposing a `KernelServices` aggregate — doing so would create an
/// import cycle between the kernel facade and this file.
abstract class ClideExtensionContext {
  String get id;

  Logger get log;
  EventBus get events;
  SettingsStore get settings;
  ThemeController get theme;
  I18n get i18n;
  PanelRegistry get panels;
  LayoutArrangement get arrangement;
  CommandRegistry get commands;
  PaletteController get palette;
  ClideClipboard get clipboard;
  FileServices get files;
  Notifications get notify;
  DialogRouter get dialog;
  TrayRegistry get tray;
  SecretsVault get secrets;
  OsBridge get os;
  NetworkStatus get net;
  FocusTracker get focus;
  ProjectManager get project;
  DaemonClient get ipc;
}

/// Sugar for i18n lookups scoped to this extension's namespace.
extension ClideExtensionContextI18n on ClideExtensionContext {
  /// `ctx.t('welcome.title', placeholder: 'clide')` →
  /// `i18n.string('welcome.title', namespace: id, placeholder: 'clide')`.
  String t(String key, {String? placeholder}) =>
      i18n.string(key, namespace: id, placeholder: placeholder);

  /// [t] with interpolation replacers.
  String tr(
    String key, {
    String? placeholder,
    List<I18nReplacer> replacers = const [],
  }) =>
      i18n.interpolated(
        key,
        namespace: id,
        placeholder: placeholder,
        replacers: replacers,
      );
}
