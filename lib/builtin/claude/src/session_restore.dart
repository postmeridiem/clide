/// The workspace's open secondary Claude sessions, remembered across restarts
/// (T-589, D-114): the claude session ids of its secondary tabs, in tab order.
///
/// Kept in app scope — `app.session.claude.<workspace hash>` — never in the
/// repo: they are this machine's transcripts. Written whenever the tabs change,
/// not at exit, so a crash doesn't lose them.
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/ipc/paths.dart' show canonicalWorkspaceKey, fnv1a64Hex;

import 'session_naming.dart';

class SecondarySessionStore {
  SecondarySessionStore(this._settings, {bool Function(String root, String id)? transcriptExists}) : _transcriptExists = transcriptExists ?? _onDisk;
  final SettingsStore _settings;
  final bool Function(String root, String id) _transcriptExists;

  static bool _onDisk(String root, String id) => File(claudeTranscriptPath(root, id)).existsSync();

  static String keyFor(String root) => 'app.session.claude.${fnv1a64Hex(canonicalWorkspaceKey(root))}';

  /// The ids remembered for [root] whose transcripts still exist — a session
  /// whose transcript is gone can't be resumed, so it is dropped silently.
  List<String> restorable(String root) => [
    for (final id in _load(root))
      if (_transcriptExists(root, id)) id,
  ];

  List<String> _load(String root) {
    final raw = _settings.get<Object>(keyFor(root));
    Object? list = raw;
    if (raw is String) {
      if (raw.isEmpty) return const [];
      try {
        list = jsonDecode(raw);
      } on FormatException {
        return const [];
      }
    }
    // A List straight from the settings file: 2.18.x wrote the JSON string
    // unquoted, so it reloads as a YAML sequence (test audit #8).
    return list is List
        ? [
            for (final e in list)
              if (e is String && e.isNotEmpty) e,
          ]
        : const [];
  }

  Future<void> save(String root, List<String> ids) => _settings.set<String>(keyFor(root), jsonEncode(ids));
}
