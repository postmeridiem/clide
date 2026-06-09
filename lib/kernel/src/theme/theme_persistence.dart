/// Persist the chosen theme and restore it across loads (T-293).
///
/// clide runs a single live [ThemeController]; this bridges it to the
/// [SettingsStore] so a choice survives a restart. On every theme change we
/// write `app.theme` (the global last-used default) and, when a repo is open,
/// `project.theme` in that repo's `.clide/settings.yaml`. Whenever the settings
/// change — notably when a repo opens and its project values load — we restore
/// the most specific saved theme: `project.theme`, else the global `app.theme`.
/// The current name already encodes the high-contrast variant (`<base>-hc`), so
/// the toggle persists for free. An unknown/removed theme name is ignored, so a
/// stale value can't wedge startup.
library;

import 'dart:async';

import 'package:clide/kernel/src/settings.dart';
import 'package:clide/kernel/src/theme/controller.dart';

void wireThemePersistence(ThemeController theme, SettingsStore settings) {
  theme.addListener(() {
    final name = theme.currentName;
    // Global default — lets a brand-new / unthemed repo inherit the last choice.
    if (settings.get<String>('app.theme') != name) {
      unawaited(settings.set<String>('app.theme', name));
    }
    // Per-repo, when one is open.
    if (settings.projectDir != null && settings.get<String>('project.theme') != name) {
      unawaited(settings.set<String>('project.theme', name));
    }
  });

  void restore() {
    final saved = settings.get<String>('project.theme') ?? settings.get<String>('app.theme');
    if (saved == null || saved == theme.currentName) return;
    if (theme.available.any((d) => d.name == saved)) theme.select(saved);
  }

  settings.addListener(restore);
  restore(); // apply the global default already loaded at boot
}
