/// Reads the clide-owned keys from `.pql/config.yaml`.
///
/// Per [D-3] clide owns pql's `ignore_files:` key (and never touches
/// pql's `.pql/` index/cache data). Per [D-4] that key is the single
/// knob for ignore layering: an ordered list of gitignore-shaped files
/// at the workspace root, with later entries winning on per-pattern
/// conflicts. This module reads the list; the matcher itself lives in
/// [IgnoreSet] (see `ignore.dart`).
///
/// Flutter-free by construction — used by daemon-side file walking and
/// the search engine, both of which run under `dart test`.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

/// The ordered list of ignore-file names to layer when walking the
/// workspace, read from `ignore_files:` in `.pql/config.yaml`.
///
/// Resolution (per D-4):
///   * config present with an explicit `ignore_files:` list → that list
///     verbatim. An empty list disables file-based exclusions entirely
///     (the built-in `.git/` etc. still apply via [IgnoreSet.builtin]).
///   * config absent / malformed / missing the key → the default
///     `[.gitignore]`, plus `.clideignore` when that file exists
///     (clide-specific deviations, per D-4).
///
/// Never throws: a missing or unparseable config falls back to the
/// default, so a broken YAML file can't silently blank the ignore set.
List<String> readIgnoreFiles(Directory root) {
  final cfg = File('${root.path}/.pql/config.yaml');
  if (cfg.existsSync()) {
    try {
      final doc = loadYaml(cfg.readAsStringSync());
      if (doc is YamlMap && doc.containsKey('ignore_files')) {
        final raw = doc['ignore_files'];
        if (raw is YamlList) {
          return [
            for (final e in raw)
              if (e is String) e,
          ];
        }
      }
    } catch (_) {
      // Malformed YAML — fall through to the default below.
    }
  }
  final names = <String>['.gitignore'];
  if (File('${root.path}/.clideignore').existsSync()) {
    names.add('.clideignore');
  }
  return names;
}
