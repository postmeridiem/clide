import 'dart:async';

import 'package:clide/extension/src/contribution.dart';
import 'package:clide/extension/src/extension.dart';
import 'package:clide/kernel/src/clipboard.dart';
import 'package:clide/kernel/src/commands/keybindings.dart';
import 'package:clide/kernel/src/commands/palette.dart';
import 'package:clide/kernel/src/reader_nav.dart';
import 'package:clide/kernel/src/commands/registry.dart';
import 'package:clide/kernel/src/dialog.dart';
import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/files.dart';
import 'package:clide/kernel/src/focus.dart';
import 'package:clide/kernel/src/i18n/i18n.dart';
import 'package:clide/kernel/src/ipc/client.dart';
import 'package:clide/kernel/src/keymap/keymap_service.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/net.dart';
import 'package:clide/kernel/src/notify.dart';
import 'package:clide/kernel/src/os.dart';
import 'package:clide/kernel/src/panels/arrangement.dart';
import 'package:clide/kernel/src/panels/registry.dart';
import 'package:clide/kernel/src/project.dart';
import 'package:clide/kernel/src/secrets.dart';
import 'package:clide/kernel/src/settings.dart';
import 'package:clide/kernel/src/settings_registry.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/tray.dart';
import 'package:flutter/foundation.dart';

class ExtensionManager extends ChangeNotifier {
  ExtensionManager({
    required this.log,
    required this.events,
    required this.messages,
    required this.settings,
    required this.theme,
    required this.i18n,
    required this.panels,
    required this.arrangement,
    required this.commands,
    required this.palette,
    required this.readerNav,
    required this.keybindings,
    required this.keymap,
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
    required this.ipc,
    required this.settingsRegistry,
  });

  final Logger log;
  final DaemonBus events;
  final MessageBus messages;
  final SettingsStore settings;
  final ThemeController theme;
  final I18n i18n;
  final PanelRegistry panels;
  final LayoutArrangement arrangement;
  final CommandRegistry commands;
  final PaletteController palette;
  final ReaderNavRegistry readerNav;
  final KeybindingResolver keybindings;
  final KeymapService keymap;
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
  final DaemonClient ipc;
  final SettingsRegistry settingsRegistry;

  final Map<String, ClideExtension> _known = {};
  final Set<String> _activated = {};
  // Extensions whose activate() / deactivate() threw — exposed so the
  // UI can show a "degraded" status next to them.
  final Map<String, Object> _failed = {};

  void register(ClideExtension ext) {
    if (_known.containsKey(ext.id)) {
      log.warn('extensions', 'duplicate registration: ${ext.id}');
      return;
    }
    _known[ext.id] = ext;
    notifyListeners();
  }

  Iterable<ClideExtension> get all => _known.values;
  bool isActivated(String id) => _activated.contains(id);

  /// Map of extension id → most recent activate/deactivate error.
  /// Cleared for an extension when it activates cleanly. UI surfaces
  /// read this for the "degraded" indicator.
  Map<String, Object> get failedExtensions => Map.unmodifiable(_failed);
  bool didFail(String id) => _failed.containsKey(id);

  bool isEnabled(String id) {
    final v = settings.get<bool>('app.extensions.$id.enabled');
    return v ?? true;
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await settings.set<bool>('app.extensions.$id.enabled', enabled);
    if (enabled && !isActivated(id)) {
      await activate(id);
    } else if (!enabled && isActivated(id)) {
      await deactivate(id);
    }
  }

  /// Activate every enabled extension in dependency order. Missing
  /// deps warn and skip.
  Future<void> activateAll() async {
    final order = _topoSort();
    for (final id in order) {
      if (!isEnabled(id)) continue;
      await activate(id);
    }
  }

  Future<void> activate(String id) async {
    if (_activated.contains(id)) return;
    final ext = _known[id];
    if (ext == null) {
      log.warn('extensions', 'unknown extension: $id');
      return;
    }
    for (final dep in ext.dependsOn) {
      if (!_activated.contains(dep)) {
        log.warn('extensions', 'skipping ${ext.id}: dependency not activated: $dep');
        return;
      }
    }
    final ctx = _ExtensionContext(manager: this, id: ext.id);
    // Transactional: a throw mid-activation must leave NOTHING mounted —
    // the old path left earlier contributions live while the extension
    // recorded as failed, and a retry double-applied them (T-377).
    final applied = <ContributionPoint>[];
    var extActivated = false;
    try {
      await ext.activate(ctx);
      extActivated = true;
      for (final c in ext.contributions) {
        _applyContribution(c);
        applied.add(c);
      }
      // Eagerly load the i18n catalog for any localized tab this extension
      // contributes, so its title resolves without a "namespace not
      // registered" warning — and without the namespace having to be listed
      // by hand at boot (T-155).
      for (final ns in {
        for (final c in ext.contributions)
          if (c is TabContribution && c.i18nNamespace != null) c.i18nNamespace!,
      }) {
        await i18n.ensureNamespaceLoaded(ns);
      }
      _activated.add(id);
      _failed.remove(id);
      events.emit(ExtensionActivated(id: id));
      notifyListeners();
      log.info('extensions', 'activated $id');
    } catch (e, st) {
      for (final c in applied.reversed) {
        try {
          _removeContribution(c);
        } catch (e2) {
          log.warn('extensions', 'unwind of ${c.id} failed during $id rollback: $e2');
        }
      }
      if (extActivated) {
        // The extension's own activate() succeeded — give it the matching
        // teardown so it doesn't hold resources for a failed activation.
        try {
          await ext.deactivate();
        } catch (e2) {
          log.warn('extensions', 'deactivate during $id rollback failed: $e2');
        }
      }
      _failed[id] = e;
      log.error('extensions', 'activate failed for $id', error: e, stackTrace: st);
      notifyListeners();
    }
  }

  Future<void> deactivate(String id) async {
    if (!_activated.contains(id)) return;
    final ext = _known[id];
    if (ext == null) return;
    // Refuse while active extensions depend on this one — deactivating
    // underneath them leaves them running against missing services (T-377).
    // Disable the dependents first.
    final dependents = [
      for (final e in _known.values)
        if (_activated.contains(e.id) && e.dependsOn.contains(id)) e.id,
    ];
    if (dependents.isNotEmpty) {
      log.warn('extensions', 'refusing to deactivate $id: active dependents: ${dependents.join(', ')}');
      return;
    }
    try {
      await ext.deactivate();
      for (final c in ext.contributions) {
        _removeContribution(c);
      }
      _activated.remove(id);
      events.emit(ExtensionDeactivated(id: id));
      notifyListeners();
      log.info('extensions', 'deactivated $id');
    } catch (e, st) {
      _failed[id] = e;
      log.error('extensions', 'deactivate failed for $id', error: e, stackTrace: st);
      notifyListeners();
    }
  }

  void _applyContribution(ContributionPoint c) {
    switch (c) {
      case TabContribution _:
      case StatusItemContribution _:
      case ToolbarButtonContribution _:
        // Reject duplicates instead of silently mounting a second copy —
        // benign among curated builtins, hazardous once third-party
        // extensions land (T-377). The throw rolls the activation back.
        if (panels.hasContribution(c.id)) {
          throw StateError('duplicate contribution id: ${c.id}');
        }
        panels.contribute(c);
      case CommandContribution cmd:
        if (commands.get(cmd.command) != null) {
          throw StateError('duplicate command id: ${cmd.command}');
        }
        commands.register(cmd);
        final binding = cmd.defaultBinding;
        if (binding != null) {
          // Legacy KeybindingResolver still wired for back-compat
          // until all callers migrate; the keymap layer is the
          // canonical home for chord → command bindings (T-117).
          keybindings.bind(Keybinding.parse(binding), cmd.command);
          keymap.registerCommandBinding(binding, cmd.command, when: cmd.bindingWhen);
        }
      case TrayItemContribution t:
        tray.add(t);
      case LayoutPresetContribution _:
        // Presets are consumed by the default-layout extension in its
        // own activate(); nothing for the kernel to do here.
        break;
      case SettingsCategoryContribution s:
        // register() throws on a duplicate id, rolling activation back.
        settingsRegistry.register(s.category);
    }
  }

  void _removeContribution(ContributionPoint c) {
    switch (c) {
      case TabContribution _:
      case StatusItemContribution _:
      case ToolbarButtonContribution _:
        panels.uncontribute(c.id);
      case CommandContribution cmd:
        commands.unregister(cmd.command);
        final binding = cmd.defaultBinding;
        if (binding != null) {
          keybindings.unbind(Keybinding.parse(binding));
        }
        keymap.unregisterCommandBindings(cmd.command);
      case TrayItemContribution t:
        tray.remove(t.id);
      case LayoutPresetContribution _:
        break;
      case SettingsCategoryContribution s:
        settingsRegistry.unregister(s.category.id);
    }
  }

  List<String> _topoSort() {
    final order = <String>[];
    final seen = <String>{};
    final visiting = <String>{};

    void visit(String id) {
      if (seen.contains(id)) return;
      if (visiting.contains(id)) {
        log.warn('extensions', 'dependency cycle touching $id');
        return;
      }
      final ext = _known[id];
      if (ext == null) return;
      visiting.add(id);
      for (final dep in ext.dependsOn) {
        visit(dep);
      }
      visiting.remove(id);
      seen.add(id);
      order.add(id);
    }

    for (final id in _known.keys) {
      visit(id);
    }
    return order;
  }
}

class _ExtensionContext implements ClideExtensionContext {
  _ExtensionContext({required this.manager, required this.id});
  final ExtensionManager manager;
  @override
  final String id;

  @override
  Logger get log => manager.log;
  @override
  DaemonBus get events => manager.events;
  @override
  MessageBus get messages => manager.messages;
  @override
  SettingsStore get settings => manager.settings;
  @override
  ThemeController get theme => manager.theme;
  @override
  I18n get i18n => manager.i18n;
  @override
  PanelRegistry get panels => manager.panels;
  @override
  LayoutArrangement get arrangement => manager.arrangement;
  @override
  CommandRegistry get commands => manager.commands;
  @override
  KeymapService get keymap => manager.keymap;
  @override
  PaletteController get palette => manager.palette;
  @override
  ReaderNavRegistry get readerNav => manager.readerNav;
  @override
  ClideClipboard get clipboard => manager.clipboard;
  @override
  FileServices get files => manager.files;
  @override
  Notifications get notify => manager.notify;
  @override
  DialogRouter get dialog => manager.dialog;
  @override
  TrayRegistry get tray => manager.tray;
  @override
  SecretsVault get secrets => manager.secrets;
  @override
  OsBridge get os => manager.os;
  @override
  NetworkStatus get net => manager.net;
  @override
  FocusTracker get focus => manager.focus;
  @override
  ProjectManager get project => manager.project;
  @override
  DaemonClient get ipc => manager.ipc;
}
