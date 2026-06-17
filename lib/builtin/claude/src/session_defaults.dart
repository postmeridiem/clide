import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/kernel/kernel.dart';

/// Per-user defaults applied to NEW Claude sessions (T-457). Set from the
/// Settings → Claude category; read by the pane when it spawns a session.
/// Effort is applied at spawn (the `--effort` flag — there's no live
/// set_effort); model and permission mode are sent as control requests right
/// after the session starts.
const String kDefaultModelKey = 'app.claude.defaultModel';
const String kDefaultEffortKey = 'app.claude.defaultEffort';
const String kDefaultPermissionModeKey = 'app.claude.defaultPermissionMode';

/// The default effort for new sessions, or null to let the CLI's own default
/// stand. `'default'` is treated as "no override" too.
String? defaultEffortFlag(SettingsStore settings) {
  final v = settings.get<String>(kDefaultEffortKey);
  if (v == null || v.isEmpty || v == 'default') return null;
  return v;
}

/// Apply the model + permission-mode defaults to a freshly-spawned [session].
/// A null/empty/`'default'` value is a no-op — the CLI's own default stands.
/// (Effort is handled at spawn via [defaultEffortFlag], not here.)
void applySessionDefaults(StreamJsonSession session, SettingsStore settings) {
  final model = settings.get<String>(kDefaultModelKey);
  if (model != null && model.isNotEmpty && model != 'default') session.setModel(model);
  final perm = settings.get<String>(kDefaultPermissionModeKey);
  if (perm != null && perm.isNotEmpty && perm != 'default') session.setPermissionMode(perm);
}
