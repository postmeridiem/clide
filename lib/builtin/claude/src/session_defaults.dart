import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/kernel/kernel.dart';

/// Per-user defaults applied to NEW Claude sessions (T-457). Set from the
/// Settings → Claude category; read by the pane when it spawns a session.
/// Effort and permission mode are applied at spawn (`--effort`,
/// `--permission-mode`); the model is sent as a control request right after
/// the session starts.
const String kDefaultModelKey = 'app.claude.defaultModel';
const String kDefaultEffortKey = 'app.claude.defaultEffort';
const String kDefaultPermissionModeKey = 'app.claude.defaultPermissionMode';

/// Auto is Anthropic's preferred starting mode (T-597). Where it isn't
/// available — the model, the plan, an admin setting — the CLI starts the
/// session in Manual by itself, so this default is safe everywhere.
const String kDefaultPermissionModeDefault = 'auto';

/// Whether sessions may enter bypassPermissions at all (T-597) — the desktop
/// app's "Allow bypass permissions mode". Off by default. When on, sessions
/// launch with `--allow-dangerously-skip-permissions`, which makes the mode
/// selectable without entering it; the CLI refuses it otherwise.
const String kAllowBypassKey = 'app.claude.allowBypassPermissions';

/// The permission mode new sessions start in (`--permission-mode`).
String defaultPermissionModeFlag(SettingsStore settings) {
  final v = settings.get<String>(kDefaultPermissionModeKey);
  if (v == null || v.isEmpty) return kDefaultPermissionModeDefault;
  // A stored bypass without the opt-in would be refused at launch.
  if (v == 'bypassPermissions' && !allowBypassPermissions(settings)) return 'default';
  return v;
}

/// Whether to launch sessions able to enter bypassPermissions.
bool allowBypassPermissions(SettingsStore settings) => settings.get<bool>(kAllowBypassKey) ?? false;

/// The default effort for new sessions, or null to let the CLI's own default
/// stand. `'default'` is treated as "no override" too.
String? defaultEffortFlag(SettingsStore settings) {
  final v = settings.get<String>(kDefaultEffortKey);
  if (v == null || v.isEmpty || v == 'default') return null;
  return v;
}

/// Apply the model default to a freshly-spawned [session]. A
/// null/empty/`'default'` value is a no-op — the CLI's own default stands.
/// (Effort and permission mode are applied at spawn, via [defaultEffortFlag]
/// and [defaultPermissionModeFlag].)
void applySessionDefaults(StreamJsonSession session, SettingsStore settings) {
  final model = settings.get<String>(kDefaultModelKey);
  if (model != null && model.isNotEmpty && model != 'default') session.setModel(model);
}
