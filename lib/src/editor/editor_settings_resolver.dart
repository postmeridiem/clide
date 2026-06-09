/// Composes the effective [EditorSettings] for a file from its sources (T-29).
///
/// This is the single seam the editor stack calls — [EditorRegistry] resolves a
/// buffer's settings here on load and whenever a source changes. Today the only
/// source is the project's `.editorconfig`; a workspace settings file or a
/// settings-panel override layers in by adding another `.merge(...)` below, in
/// increasing-precedence order. The editor and save path never learn the
/// source — they only see the merged result.
library;

import 'dart:io';

import 'editor_settings.dart';
import 'editorconfig.dart';

/// The merged settings for [relPath] (workspace-relative, `/`-separated).
EditorSettings resolveEditorSettings(Directory workspaceRoot, String relPath) {
  // Lowest precedence first; later sources override earlier ones.
  var settings = EditorSettings.empty;
  settings = settings.merge(readEditorConfig(workspaceRoot, relPath));
  // Future sources slot in here, e.g.:
  //   settings = settings.merge(readWorkspaceSettingsFile(workspaceRoot, relPath));
  //   settings = settings.merge(settingsPanelOverrides(relPath));
  return settings;
}
