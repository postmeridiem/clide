import 'dart:async';

import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart' show kLocaleSettingKey;
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Whether closing the window hides it to the tray/Dock (D-110).
const String kCloseToTrayKey = 'app.closeToTray';
const bool kCloseToTrayDefault = true;

/// The persisted log verbosity (T-433). Also written by `clide log level` and
/// the Output dock's level chip, which apply it themselves.
const String kLogLevelKey = 'app.log.level';

/// App-wide concerns that belong to no single feature (settings restructure,
/// T-590): the **General** settings category, and the window lifecycle behind
/// the tray/Dock (D-110) — close-to-tray policy, the tray menu's labels and
/// workspace name, and the hide / quit / quit-all commands.
class AppExtension extends ClideExtension {
  @override
  String get id => 'builtin.app';
  @override
  String get title => 'App';
  @override
  String get version => '0.1.0';

  ClideExtensionContext? _ctx;
  StreamSubscription<ProjectOpened>? _projectSub;
  bool? _closeToTray;
  String? _logLevel;

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    ctx.tray.attachNative();
    // What was persisted at boot is already applied (main.dart resolves it,
    // possibly under an env override) — only react to changes from here on.
    _logLevel = ctx.settings.get<String>(kLogLevelKey);
    ctx.settings.addListener(_onSettings);
    _pushCloseToTray();
    // activate() runs before the manager loads this extension's catalog, and
    // native has no catalog of its own — load it now, and re-push on a
    // locale change so the tray menu follows the app's language.
    await ctx.i18n.ensureNamespaceLoaded(id);
    _pushLabels();
    ctx.i18n.addListener(_pushLabels);
    final current = ctx.project.current?.path;
    if (current != null) unawaited(ctx.tray.setWorkspace(current));
    _projectSub = ctx.events.on<ProjectOpened>().listen((e) => unawaited(ctx.tray.setWorkspace(e.path)));
  }

  @override
  Future<void> deactivate() async {
    _ctx?.settings.removeListener(_onSettings);
    _ctx?.i18n.removeListener(_pushLabels);
    await _projectSub?.cancel();
  }

  void _pushLabels() {
    final ctx = _ctx;
    if (ctx != null) unawaited(ctx.tray.setLabels(trayLabels(ctx)));
  }

  void _onSettings() {
    _pushCloseToTray();
    _applyLogLevel();
  }

  void _pushCloseToTray() {
    final ctx = _ctx;
    if (ctx == null) return;
    final v = ctx.settings.get<bool>(kCloseToTrayKey) ?? kCloseToTrayDefault;
    if (v == _closeToTray) return;
    _closeToTray = v;
    unawaited(ctx.tray.setCloseToTray(v));
  }

  /// A level picked in the panel only persists the setting — unlike the CLI
  /// verb and the dock chip, nothing else sets the logger. Apply on change.
  void _applyLogLevel() {
    final ctx = _ctx;
    if (ctx == null) return;
    final raw = ctx.settings.get<String>(kLogLevelKey);
    if (raw == _logLevel) return;
    _logLevel = raw;
    final level = LogLevel.values.where((l) => l.name == raw).firstOrNull;
    if (level != null && ctx.log.minLevel != level) ctx.log.minLevel = level;
  }

  @override
  List<ContributionPoint> get contributions => [
    CommandContribution(
      id: 'window.hideToTray',
      command: 'window.hideToTray',
      title: 'Window: Hide to Tray',
      titleKey: 'command.hideToTray',
      i18nNamespace: id,
      run: (_) => _windowOp((t) => t.hide(), 'nothing can bring the window back — no tray host'),
    ),
    CommandContribution(
      id: 'window.quit',
      command: 'window.quit',
      title: 'Quit this Window',
      titleKey: 'command.quit',
      i18nNamespace: id,
      run: (_) => _windowOp((t) => t.quit(all: false), 'quit is not supported on this platform'),
    ),
    CommandContribution(
      id: 'window.quitAll',
      command: 'window.quitAll',
      title: 'Quit clide (All Windows)',
      titleKey: 'command.quitAll',
      i18nNamespace: id,
      run: (_) => _windowOp((t) => t.quit(all: true), 'quit is not supported on this platform'),
    ),
    SettingsCategoryContribution(
      id: 'general',
      category: SettingsCategory(
        id: 'general',
        title: 'General',
        titleKey: 'settings.title',
        i18nNamespace: id,
        iconName: 'gear-six',
        priority: 5,
        sections: [
          SettingsSection(
            label: 'Window',
            labelKey: 'settings.section.window',
            fields: [
              SettingsField(
                key: kCloseToTrayKey,
                kind: SettingsFieldKind.toggle,
                label: 'Keep running when the window closes',
                labelKey: 'settings.field.closeToTray.label',
                help:
                    'Closing the window hides it to the tray (the Dock on macOS) so Claude sessions and terminals keep running. '
                    'Quit from the tray menu. Without a tray, closing always quits.',
                helpKey: 'settings.field.closeToTray.help',
                defaultValue: kCloseToTrayDefault,
              ),
            ],
          ),
          SettingsSection(
            label: 'Language',
            labelKey: 'settings.section.language',
            fields: [
              SettingsField(
                key: kLocaleSettingKey,
                kind: SettingsFieldKind.select,
                label: 'Language',
                labelKey: 'settings.field.language.label',
                help: 'Language for the app interface; applies live.',
                helpKey: 'settings.field.language.help',
                defaultValue: 'en_US',
                // Language names stay in their own language (no labelKey).
                options: [
                  SettingsOption(value: 'en_US', label: 'English'),
                  SettingsOption(value: 'nl_NL', label: 'Nederlands'),
                ],
              ),
            ],
          ),
          SettingsSection(
            label: 'Diagnostics',
            labelKey: 'settings.section.diagnostics',
            fields: [
              SettingsField(
                key: kLogLevelKey,
                kind: SettingsFieldKind.select,
                label: 'Log level',
                labelKey: 'settings.field.logLevel.label',
                help: 'How much clide writes to its log and the Output dock. Same as `clide log level`.',
                helpKey: 'settings.field.logLevel.help',
                defaultValue: LogLevel.info.name,
                options: [for (final l in LogLevel.values) SettingsOption(value: l.name, label: l.name)],
              ),
            ],
          ),
        ],
      ),
    ),
  ];

  Future<IpcResponse> _windowOp(Future<bool> Function(TrayRegistry) op, String refusal) async {
    final ctx = _ctx;
    if (ctx == null || !await op(ctx.tray)) {
      return IpcResponse.err(
        id: '',
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: ctx == null ? 'app extension not activated' : refusal),
      );
    }
    return IpcResponse.ok(id: '', data: const {});
  }
}

/// The shared tray menu's labels, localized here because native has no
/// catalog. `{workspace}`-free: native appends window names itself.
@visibleForTesting
Map<String, String> trayLabels(ClideExtensionContext ctx) => {
  'tooltip': ctx.t('tray.tooltip', placeholder: 'clide'),
  'showAll': ctx.t('tray.showAll', placeholder: 'Show all windows'),
  'hideAll': ctx.t('tray.hideAll', placeholder: 'Hide all windows'),
  'quitAll': ctx.t('tray.quitAll', placeholder: 'Quit clide'),
  'noWorkspace': ctx.t('tray.noWorkspace', placeholder: 'clide (no project)'),
};
