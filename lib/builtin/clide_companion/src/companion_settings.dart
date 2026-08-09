/// Clide companion preferences and the kill switch (T-527, D-107).
///
/// Flutter-free on purpose. The switch has to be readable **without the strip
/// being mounted** — Epic D's session lifecycle consults it before spawning a
/// process, and that code path has no `BuildContext` — so this is a plain view
/// over a key-reader function, the same shape `supporterBinariesFrom` uses.
///
/// **Scope is per repository, not per machine.** The companion is a second model
/// session reading the conversation, and whether that is acceptable is a
/// property of the work rather than of the box it runs on: a repo may be under
/// terms where an extra stream out is simply not allowed, while the next one
/// over is fine. A machine-wide switch would force the strictest repo's answer
/// on all of them. The one exception is [kCompanionSuspendWhenMinimisedKey],
/// which is about power and belongs to the machine.
library;

/// Whether the companion exists at all for this repo. **The kill switch.**
///
/// Off means off: no session, no process, and no strip — the detail views get
/// their height back and the only way to find Clide again is settings. That
/// completeness is the point (D-107 commitment 1). A face that is hidden but
/// still spawning `claude` and drawing on the same subscription quota as the
/// primary session is exactly the failure this key exists to prevent.
const kCompanionEnabledKey = 'project.companion.enabled';

/// Whether the strip is open, as opposed to minimised to its rail button.
///
/// Distinct from [kCompanionEnabledKey] and deliberately so: this is the *this
/// session* control (T-528) and that is the permanent one. Persisted per repo
/// so a workspace reopens the way it was left.
const kCompanionOpenKey = 'project.companion.open';

/// How eagerly Clide speaks. See [CompanionFrequency].
const kCompanionFrequencyKey = 'project.companion.frequency';

/// Whether to tear the companion down while the window is minimised — the
/// power ladder's `night` rung (D-107 commitment 4; T-517 owns the capability,
/// this is only the preference).
///
/// App-scoped, unlike its neighbours: this is about not heating the machine,
/// which is a property of the machine.
const kCompanionSuspendWhenMinimisedKey = 'app.companion.suspendWhenMinimised';

/// On by default — the strip ships visible, and a companion nobody can find is
/// not a feature. The safety argument that would normally push a
/// quota-spending default to *off* is answered by the scope instead: a repo
/// where this is unacceptable turns it off once, for that repo, permanently.
const kCompanionEnabledDefault = true;

/// Open by default, matching [kCompanionEnabledDefault] — enabling and then
/// having to also un-minimise would be two steps for one intent.
const kCompanionOpenDefault = true;

const kCompanionSuspendWhenMinimisedDefault = true;

/// How readily Clide comments. D-107 fixes the *shape* — notable events only,
/// never per-token — and this tunes the threshold within it.
enum CompanionFrequency {
  /// Failures and long runs only. The setting for someone who wants the face
  /// and the rain but rarely the voice.
  rare,

  /// The D-107 default: turn finished, error, long run crossing a threshold,
  /// commit landed.
  notable,

  /// Also comments on ordinary turns. Costs the most quota; still never
  /// per-token.
  chatty;

  static CompanionFrequency parse(Object? raw) {
    return CompanionFrequency.values.firstWhere((f) => f.name == raw, orElse: () => CompanionFrequency.notable);
  }
}

/// A read-only view of the companion's preferences.
///
/// Construct from anything that can look a key up — a `SettingsStore`, a test
/// map — so the kill switch is checkable from the session layer, from a widget,
/// and from a unit test without any of them sharing machinery.
class ClideCompanionSettings {
  const ClideCompanionSettings(this._read);

  /// Reads a raw stored value, or null when unset.
  final Object? Function(String key) _read;

  /// Every preference at its default. For code that must answer before a store
  /// exists.
  static const defaults = ClideCompanionSettings(_noValues);

  static Object? _noValues(String _) => null;

  bool get enabled => _bool(kCompanionEnabledKey, kCompanionEnabledDefault);

  bool get open => _bool(kCompanionOpenKey, kCompanionOpenDefault);

  bool get suspendWhenMinimised => _bool(kCompanionSuspendWhenMinimisedKey, kCompanionSuspendWhenMinimisedDefault);

  CompanionFrequency get frequency => CompanionFrequency.parse(_read(kCompanionFrequencyKey));

  /// **The gate.** Whether a companion session may exist right now.
  ///
  /// Epic D (T-519) must consult this before spawning, and again whenever the
  /// key changes — disabling has to tear the process down, not merely stop new
  /// ones. Named for the question rather than for the key so the call site
  /// reads as a permission check, which is what it is.
  bool get mayRunSession => enabled;

  /// Whether the strip should be in the widget tree at all. False when the
  /// companion is disabled for this repo — the height goes back to the detail
  /// view rather than the face merely going quiet.
  bool get stripVisible => enabled;

  bool _bool(String key, bool fallback) {
    final v = _read(key);
    return v is bool ? v : fallback;
  }
}
