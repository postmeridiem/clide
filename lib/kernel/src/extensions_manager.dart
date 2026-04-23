import 'dart:async';

import 'package:clide/extension/src/contribution.dart';
import 'package:clide/extension/src/extension.dart';
import 'package:clide/kernel/src/clipboard.dart';
import 'package:clide/kernel/src/commands/keybindings.dart';
import 'package:clide/kernel/src/commands/palette.dart';
import 'package:clide/kernel/src/commands/registry.dart';
import 'package:clide/kernel/src/dialog.dart';
import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/files.dart';
import 'package:clide/kernel/src/focus.dart';
import 'package:clide/kernel/src/i18n/i18n.dart';
import 'package:clide/kernel/src/ipc/client.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/net.dart';
import 'package:clide/kernel/src/notify.dart';
import 'package:clide/kernel/src/os.dart';
import 'package:clide/kernel/src/panels/arrangement.dart';
import 'package:clide/kernel/src/panels/registry.dart';
import 'package:clide/kernel/src/project.dart';
import 'package:clide/kernel/src/secrets.dart';
import 'package:clide/kernel/src/settings.dart';
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
    required this.ipc,
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
  final DaemonClient ipc;

  final Map<String, ClideExtension> _known = {};
  final Set<String> _activated = {};

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
        log.warn(
            'extensions', 'skipping ${ext.id}: dependency not activated: $dep');
        return;
      }
    }
    final ctx = _ExtensionContext(manager: this, id: ext.id);
    try {
      await ext.activate(ctx);
      for (final c in ext.contributions) {
        _applyContribution(c);
      }
      _activated.add(id);
      events.emit(ExtensionActivated(id: id));
      notifyListeners();
      log.info('extensions', 'activated $id');
    } catch (e, st) {
      log.error('extensions', 'activate failed for $id',
          error: e, stackTrace: st);
    }
  }

  Future<void> deactivate(String id) async {
    if (!_activated.contains(id)) return;
    final ext = _known[id];
    if (ext == null) return;
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
      log.error('extensions', 'deactivate failed for $id',
          error: e, stackTrace: st);
    }
  }

  void _applyContribution(ContributionPoint c) {
    switch (c) {
      case TabContribution _:
      case StatusItemContribution _:
      case ToolbarButtonContribution _:
        panels.contribute(c);
      case CommandContribution cmd:
        commands.register(cmd);
        final binding = cmd.defaultBinding;
        if (binding != null) {
          keybindings.bind(Keybinding.parse(binding), cmd.command);
        }
      case TrayItemContribution t:
        tray.add(t);
      case LayoutPresetContribution _:
        // Presets are consumed by the default-layout extension in its
        // own activate(); nothing for the kernel to do here.
        break;
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
      case TrayItemContribution t:
        tray.remove(t.id);
      case LayoutPresetContribution _:
        break;
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
  PaletteController get palette => manager.palette;
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
