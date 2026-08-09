/// The Clide companion builtin (T-527, D-107): the settings category, the kill
/// switch, and the adapter between the preference store and the MessageBus.
///
/// The adapter is the whole job here. Preferences persist; the bus carries
/// change. Keeping those two in one place means every other surface —
/// the strip, the rail button (T-528), the CLI verbs (T-529), the session
/// (T-519) — only has to know one of them, and none of them has to know each
/// other.
///
/// One direction each way:
///  * `companion.set` arrives → write the preference → announce `companion.state`.
///  * the store changes by any other route (the settings panel writes directly)
///    → announce `companion.state`.
///
/// So the announcement is emitted from exactly one place regardless of who
/// caused the change, and no surface can report a state that was not persisted.
library;

import 'dart:async';

import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/builtin/clide_companion/src/load_adapter.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

class ClideCompanionExtension extends ClideExtension {
  ClideExtensionContext? _ctx;
  StreamSubscription<Message>? _sets;
  CompanionLoadAdapter? _load;

  /// Last announced state, so a settings notification about somebody else's key
  /// — the store notifies on every write — does not republish ours.
  ///
  /// Stored as **values, not as a [ClideCompanionSettings]**. That type is a
  /// live view over the store, so holding one here would compare the store
  /// against itself: always equal, and no announcement would ever be published.
  ({bool enabled, bool open, String frequency})? _announced;

  /// Must match the namespace the face's semantics labels already use.
  @override
  String get id => 'builtin.clide-companion';

  @override
  String get title => 'Clide';

  @override
  String get version => '0.1.0';

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    _sets = ctx.messages.subscribe(publisher: clideCompanionPublisher, channel: companionSetChannel).listen(_onSet);
    ctx.settings.addListener(_onSettingsChanged);
    // Seed: announce once so anything already mounted agrees with the store.
    // Late subscribers seed themselves from the store instead — the bus does
    // not retain.
    _announce();

    // The primary session's load — the rain's input (T-538). Started here rather
    // than by the strip so it is bound once for the app, not once per widget
    // that happens to be mounted.
    _load = CompanionLoadAdapter(messages: ctx.messages)..start(activeSessionOrchestrator);
  }

  @override
  Future<void> deactivate() async {
    await _sets?.cancel();
    _load?.dispose();
    _load = null;
    _ctx?.settings.removeListener(_onSettingsChanged);
    _ctx = null;
  }

  ClideCompanionSettings get _prefs {
    final ctx = _ctx;
    if (ctx == null) return ClideCompanionSettings.defaults;
    return ClideCompanionSettings((k) => ctx.settings.get<Object>(k));
  }

  /// Apply a requested change. Writes first, announces second — a surface that
  /// optimistically rendered the request would be showing a state that might
  /// not have persisted.
  Future<void> _onSet(Message m) async {
    final ctx = _ctx;
    if (ctx == null) return;
    for (final key in const [kCompanionEnabledKey, kCompanionOpenKey]) {
      final field = key == kCompanionEnabledKey ? 'enabled' : 'open';
      final v = m.data[field];
      if (v is bool) await ctx.settings.set(key, v);
    }
    final freq = m.data['frequency'];
    if (freq is String) await ctx.settings.set(kCompanionFrequencyKey, CompanionFrequency.parse(freq).name);
    _announce();
  }

  void _onSettingsChanged() => _announce();

  void _announce() {
    final ctx = _ctx;
    if (ctx == null) return;
    final prefs = _prefs;
    final now = (enabled: prefs.enabled, open: prefs.open, frequency: prefs.frequency.name);
    if (_announced == now) return;
    _announced = now;
    publishCompanionState(ctx.messages, enabled: now.enabled, open: now.open, frequency: now.frequency);
  }

  @override
  List<ContributionPoint> get contributions => [
    SettingsCategoryContribution(
      id: 'clide-companion',
      category: SettingsCategory(
        id: 'clide-companion',
        title: 'Clide',
        titleKey: 'settings.title',
        i18nNamespace: id,
        iconName: 'smiley',
        priority: 65,
        sections: [
          SettingsSection(
            label: 'Companion',
            labelKey: 'settings.section.companion',
            fields: [
              SettingsField(
                key: kCompanionEnabledKey,
                kind: SettingsFieldKind.toggle,
                label: 'Enable Clide',
                labelKey: 'settings.field.enabled.label',
                help:
                    'Runs a second Claude session for this repository that watches the conversation and comments on it. '
                    'It spends the same subscription quota as your main session. Off removes it entirely — no session, no strip.',
                helpKey: 'settings.field.enabled.help',
                defaultValue: kCompanionEnabledDefault,
              ),
              SettingsField(
                key: kCompanionFrequencyKey,
                kind: SettingsFieldKind.select,
                label: 'How often it speaks',
                labelKey: 'settings.field.frequency.label',
                help: 'Never per message — this sets how notable an event has to be before Clide remarks on it.',
                helpKey: 'settings.field.frequency.help',
                defaultValue: CompanionFrequency.notable.name,
                options: [
                  SettingsOption(value: CompanionFrequency.rare.name, label: 'Rarely — errors and long runs', labelKey: 'settings.field.frequency.rare'),
                  SettingsOption(value: CompanionFrequency.notable.name, label: 'Notable events', labelKey: 'settings.field.frequency.notable'),
                  SettingsOption(value: CompanionFrequency.chatty.name, label: 'Chatty', labelKey: 'settings.field.frequency.chatty'),
                ],
              ),
            ],
          ),
          SettingsSection(
            label: 'Power',
            labelKey: 'settings.section.power',
            fields: [
              SettingsField(
                key: kCompanionSuspendWhenMinimisedKey,
                kind: SettingsFieldKind.toggle,
                label: 'Suspend while the window is minimised',
                labelKey: 'settings.field.suspend.label',
                help: 'Stops the animation and tears the session down while you are not looking at it.',
                helpKey: 'settings.field.suspend.help',
                defaultValue: kCompanionSuspendWhenMinimisedDefault,
              ),
            ],
          ),
        ],
      ),
    ),
  ];
}
