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
import 'package:clide/builtin/clide_companion/src/companion_lifecycle.dart';
import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

class ClideCompanionExtension extends ClideExtension {
  ClideExtensionContext? _ctx;
  StreamSubscription<Message>? _sets;

  /// Owns the companion process (T-545). Held here because the two facts that
  /// decide whether it may run — the kill switch and the strip's open state —
  /// are preferences, and preferences are already this class's job.
  CompanionSessionController? _session;

  /// Exposed for the surfaces that will read the companion's conversation
  /// (T-546 onward). Null before activation.
  CompanionSessionController? get sessionController => _session;

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
    ctx.project.addListener(_onProjectChanged);
    _session = CompanionSessionController();
    // Seed: announce once so anything already mounted agrees with the store.
    // Late subscribers seed themselves from the store instead — the bus does
    // not retain.
    _announce();
    await _syncSession();
    // The primary session's load is no longer relayed from here (T-561): the
    // strip binds a `SessionReader` itself, so the extension owns preferences
    // and nothing else.
  }

  @override
  Future<void> deactivate() async {
    await _sets?.cancel();
    _ctx?.settings.removeListener(_onSettingsChanged);
    _ctx?.project.removeListener(_onProjectChanged);
    await _session?.shutdown();
    _session = null;
    _ctx = null;
  }

  /// Push the current desired state at the session controller.
  ///
  /// Called on activation and on **every** settings notification, not only when
  /// something companion-shaped changed: the controller compares before acting,
  /// and the alternative — deciding here what counts as relevant — is how a kill
  /// switch quietly stops killing.
  Future<void> _syncSession() async {
    final ctx = _ctx;
    final controller = _session;
    if (ctx == null || controller == null) return;
    final prefs = _prefs;
    await controller.sync(enabled: prefs.mayRunSession, open: prefs.open, root: ctx.project.current?.path);
  }

  void _onProjectChanged() => unawaited(_syncSession());

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

  void _onSettingsChanged() {
    _announce();
    unawaited(_syncSession());
  }

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
          // Injected into Clide's brief once, at spawn (T-532). Changing any of
          // these changes the prompt, so it restarts him — the same rule the
          // language setting follows, and for the same reason.
          SettingsSection(
            label: 'You',
            labelKey: 'settings.section.you',
            fields: [
              SettingsField(
                key: kCompanionUserNameKey,
                kind: SettingsFieldKind.text,
                label: 'Your name',
                labelKey: 'settings.field.userName.label',
                help: 'What Clide knows you as. He is told once and told not to use it out loud.',
                helpKey: 'settings.field.userName.help',
                defaultValue: '',
              ),
              SettingsField(
                key: kCompanionAboutKey,
                kind: SettingsFieldKind.text,
                label: 'Describe yourself to Clide',
                labelKey: 'settings.field.about.label',
                help: 'A line or two in your own words, quoted into his brief. The one place you shape his character directly.',
                helpKey: 'settings.field.about.help',
                defaultValue: '',
              ),
              SettingsField(
                key: kCompanionMoodChannelKey,
                kind: SettingsFieldKind.toggle,
                label: 'Let Clide choose his own expression',
                labelKey: 'settings.field.moodChannel.label',
                help:
                    'He names how he feels on each remark and the face follows. Off, his expression comes from what his session is doing. '
                    'Changing this restarts him.',
                helpKey: 'settings.field.moodChannel.help',
                defaultValue: kCompanionMoodChannelDefault,
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
