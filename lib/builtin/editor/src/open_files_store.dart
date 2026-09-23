/// The workspace's open editor files, remembered across restarts (D-114): the
/// buffers' paths in tab order, the active one, and whether the editor split
/// was showing.
///
/// App scope — `app.session.editor.<workspace hash>` — never the repo. Written
/// as the buffers change, so a crash doesn't lose it.
library;

import 'dart:convert';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/ipc/paths.dart' show canonicalWorkspaceKey, fnv1a64Hex;

class OpenFiles {
  const OpenFiles({this.paths = const [], this.active, this.visible = false});
  final List<String> paths;
  final String? active;
  final bool visible;

  bool sameAs(OpenFiles o) => visible == o.visible && active == o.active && paths.length == o.paths.length && _samePaths(o);

  bool _samePaths(OpenFiles o) {
    for (var i = 0; i < paths.length; i++) {
      if (paths[i] != o.paths[i]) return false;
    }
    return true;
  }
}

class OpenFilesStore {
  OpenFilesStore(this._settings);
  final SettingsStore _settings;

  static String keyFor(String root) => 'app.session.editor.${fnv1a64Hex(canonicalWorkspaceKey(root))}';

  OpenFiles load(String root) {
    final raw = _settings.get<String>(keyFor(root));
    if (raw == null || raw.isEmpty) return const OpenFiles();
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return const OpenFiles();
      final paths = j['files'];
      return OpenFiles(
        paths: paths is List
            ? [
                for (final p in paths)
                  if (p is String && p.isNotEmpty) p,
              ]
            : const [],
        active: j['active'] is String ? j['active'] as String : null,
        visible: j['visible'] == true,
      );
    } on FormatException {
      return const OpenFiles();
    }
  }

  Future<void> save(String root, OpenFiles f) => _settings.set<String>(keyFor(root), jsonEncode({'files': f.paths, 'active': ?f.active, 'visible': f.visible}));
}
