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
import 'package:clide/builtin/clide_companion/src/companion_ledger.dart';
import 'package:clide/builtin/clide_companion/src/companion_lifecycle.dart';
import 'package:clide/builtin/clide_companion/src/prompt/brief_loader.dart';
import 'package:clide/builtin/clide_companion/src/prompt/companion_prompt.dart';
import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:flutter/foundation.dart';
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

  /// What Clide has spent this run (T-556).
  ///
  /// Owned here rather than by the popout, because it must outlive every
  /// surface that shows it: the window is opened and dismissed freely, and a
  /// total that started over each time it was looked at would be worthless. It
  /// tracks the session by id, so his restarts are invisible to it.
  CompanionLedger? _ledger;

  CompanionLedger? get ledger => _ledger;

  /// Bumped to ask the strip to open his conversation (T-567).
  ///
  /// A counter rather than a bool: two consecutive opens are two events, and a
  /// flag would swallow the second. A notifier rather than a `GlobalKey` into
  /// the strip's private state — the extension asks, the surface decides, and
  /// neither needs a handle on the other's internals.
  final ValueNotifier<int> openRequests = ValueNotifier(0);

  /// Bumped to ask the strip to focus his input.
  final ValueNotifier<int> focusRequests = ValueNotifier(0);

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
    ctx.i18n.addListener(_onLocaleChanged);
    _session = CompanionSessionController();
    _ledger = CompanionLedger()..start();
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
    _ctx?.i18n.removeListener(_onLocaleChanged);
    await _session?.shutdown();
    _session = null;
    _ledger?.dispose();
    _ledger = null;
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
    final root = await _workspaceRoot(ctx);
    final brief = await _brief(ctx, prefs);
    if (prefs.mayRunSession && (root == null || brief == null)) {
      // Deciding not to run is legitimate; doing it silently is not. This exact
      // combination — enabled, but no workspace — is what shipped first and it
      // presented as "the companion is broken" with nothing anywhere to say why.
      ctx.log.info('companion', 'not started: ${root == null ? 'no workspace root' : 'no brief for the active locale'}');
    }
    await controller.sync(enabled: prefs.mayRunSession, open: prefs.open, root: root, brief: brief, frequency: prefs.frequency);
  }

  /// Where Clide watches.
  ///
  /// **The same answer the Claude pane uses**, which is `files.root` over IPC —
  /// not `ProjectManager.current`. Those two disagree, and the disagreement is
  /// not theoretical: on a launch where no recent workspace carries the sticky
  /// flag, `openStickyOrNothing` leaves `current` null while the pane resolves a
  /// root anyway and spawns into it. The companion then had no workspace, no
  /// session, and no complaint.
  ///
  /// `ProjectManager` stays as the fallback and as the *change* signal — it is
  /// what notifies on a workspace switch — but it is not the source of truth for
  /// where we are.
  Future<String?> _workspaceRoot(ClideExtensionContext ctx) async {
    final current = ctx.project.current?.path;
    if (current != null) return current;
    try {
      final resp = await ctx.ipc.request('files.root');
      final path = resp.ok ? resp.data['path'] as String? : null;
      return (path?.isEmpty ?? true) ? null : path;
    } catch (_) {
      // No IPC yet (early boot, headless test). Absent, not broken.
      return null;
    }
  }

  /// Compose Clide's system prompt: the locale's brief document, with the
  /// developer's name, their self-description and the face vocabulary filled in
  /// (T-532).
  ///
  /// Recomposed on every sync rather than cached, because every input to it is a
  /// live preference. The controller compares the result and only respawns when
  /// it actually differs, so recomposing costs a string build and nothing else —
  /// and caching here would be a second place for "did the prompt change" to be
  /// decided, which is how a rename silently fails to take effect.
  Future<String?> _brief(ClideExtensionContext ctx, ClideCompanionSettings prefs) async {
    final loaded = await loadCompanionBrief(locale: ctx.i18n.currentLocale, defaultLocale: ctx.i18n.defaultLocale);
    if (loaded == null) return null;
    return composeSystemPrompt(brief: loaded.text, localeSuffix: loaded.foundIn, name: prefs.userName, about: prefs.about);
  }

  /// Ask the strip to do something, and refuse when there is no strip.
  ///
  /// Found reviewing T-567: these bumped their counter and reported success
  /// whether or not anything was listening. With the companion disabled or
  /// minimised the strip is not mounted, so `companion.open` answered "opened"
  /// about a window that never appeared — the same false success the `ask` verb
  /// was written to avoid, two tickets later.
  ///
  /// The mount condition is `enabled && open`, matching `CompanionState`. It is
  /// checked rather than counting listeners, because a listener count is a fact
  /// about our wiring and this is a question about the user's screen.
  Future<IpcResponse> _askSurface(ValueNotifier<int> requests, String status) async {
    final prefs = _prefs;
    if (!prefs.enabled || !prefs.open) {
      return IpcResponse.err(
        id: '',
        error: IpcError(
          code: 1,
          kind: 'no-surface',
          message: prefs.enabled ? 'the Clide strip is minimised — run companion.show first' : 'Clide is disabled for this repository',
        ),
      );
    }
    requests.value++;
    return IpcResponse.ok(id: '', data: {'status': status});
  }

  /// Drive a preference change the way the UI does — over `companion.set`, so
  /// the extension applies it, persists it, and announces it from one place.
  Future<IpcResponse> _set({bool? enabled, bool? open, String? frequency}) async {
    final ctx = _ctx;
    if (ctx == null) {
      return IpcResponse.err(
        id: '',
        error: IpcError(code: 1, kind: 'inactive', message: 'the companion is not active'),
      );
    }
    publishCompanionSet(ctx.messages, enabled: enabled, open: open, frequency: frequency);
    return IpcResponse.ok(id: '', data: const {'status': 'set'});
  }

  void _onProjectChanged() => unawaited(_syncSession());

  /// The UI language changed, so Clide's instructions did (T-558).
  ///
  /// His brief is a locale-routed document (T-532) and the prompt is argv, so a
  /// language change cannot be applied to a running process — the controller
  /// sees a different brief and replaces the session. No new mechanism: this is
  /// the same desired-state path the kill switch and a workspace switch take.
  ///
  /// **Listening to i18n rather than to the `app.locale` setting is the point.**
  /// Both notifications exist, but the settings one races: `root_shell` reacts to
  /// the same store to call `setLocale`, and if our listener runs first we
  /// compose the brief from the locale that is on its way out and decide nothing
  /// changed. `I18n` notifies once, after the catalogs are loaded, which is the
  /// only moment the new locale is actually true.
  ///
  /// Two accepted consequences, both from the ticket: the visible conversation
  /// is his transcript, so a restart starts an empty one; and `app.locale` is
  /// app-scoped while he is per-repo, so one language change restarts every
  /// workspace's companion. Both are correct for a deliberate, rare act.
  void _onLocaleChanged() => unawaited(_syncSession());

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

  /// The last thing he said, for a reader that cannot see the bubble.
  ///
  /// **A pull, not a push** (T-567, D-20). A remark announcing itself through a
  /// live region would interrupt a screen-reader user part-way through Claude's
  /// actual output, which is the content that matters — so nothing here is
  /// announced, and this exists to be asked.
  /// Written by the surface as it renders, so the verb and the bubble cannot
  /// disagree about what he last said.
  String? lastRemark;

  @override
  List<ContributionPoint> get contributions => [
    // -- The strip's chrome (T-529, D-6) --------------------------------------
    //
    // The strip is not a slot, so none of this came free — D-107 accepts the
    // parity as hand-rolled. Each of these drives `companion.set` on the bus,
    // which is the same path the rail button and the settings panel take: the
    // extension applies it, persists it, and announces the result. One route in
    // means the CLI cannot set a state the UI would disagree with.
    //
    // `show`/`hide` rather than a single toggle: a toggle cannot be made
    // idempotent, so a script has no way to *ensure* a state — which is most of
    // what an agent wants from a verb.
    CommandContribution(
      id: 'companion.show',
      command: 'companion.show',
      title: 'Clide: show the strip',
      titleKey: 'command.show',
      i18nNamespace: id,
      run: (_) async => _set(open: true),
    ),
    CommandContribution(
      id: 'companion.hide',
      command: 'companion.hide',
      title: 'Clide: minimise the strip',
      titleKey: 'command.hide',
      i18nNamespace: id,
      run: (_) async => _set(open: false),
    ),
    CommandContribution(
      id: 'companion.enable',
      command: 'companion.enable',
      title: 'Clide: enable for this repository',
      titleKey: 'command.enable',
      i18nNamespace: id,
      run: (_) async => _set(enabled: true),
    ),
    CommandContribution(
      id: 'companion.disable',
      command: 'companion.disable',
      title: 'Clide: disable for this repository',
      titleKey: 'command.disable',
      i18nNamespace: id,
      run: (_) async => _set(enabled: false),
    ),
    CommandContribution(
      id: 'companion.frequency',
      command: 'companion.frequency',
      title: 'Clide: how often he speaks',
      titleKey: 'command.frequency',
      i18nNamespace: id,
      run: (args) async {
        if (args.isEmpty) return IpcResponse.ok(id: '', data: {'frequency': _prefs.frequency.name});
        final raw = args.first.trim();
        final parsed = CompanionFrequency.parse(raw);
        // `parse` falls back to `notable` for junk, which is right for a stored
        // value and wrong for a command: a typo would silently set something
        // the caller did not ask for.
        if (parsed.name != raw) {
          return IpcResponse.err(
            id: '',
            error: IpcError(code: 1, kind: 'bad-args', message: 'frequency must be one of: ${CompanionFrequency.values.map((f) => f.name).join(', ')}'),
          );
        }
        return _set(frequency: parsed.name);
      },
    ),
    CommandContribution(
      id: 'companion.status',
      command: 'companion.status',
      title: 'Clide: report his state',
      titleKey: 'command.status',
      i18nNamespace: id,
      run: (_) async {
        final prefs = _prefs;
        // `running` is deliberately separate from `enabled`: enabled is what the
        // user asked for, running is what is true. They differ while a spawn is
        // in flight, or when there is no workspace to run in — and a status verb
        // that conflated them would report a companion that is not there.
        return IpcResponse.ok(
          id: '',
          data: {'enabled': prefs.enabled, 'open': prefs.open, 'frequency': prefs.frequency.name, 'running': _session?.running ?? false},
        );
      },
    ),
    // The stat the popout shows, as data (T-556, D-6). Worth a verb of its own
    // rather than a field on `companion.status`: that verb answers "is he on",
    // which a script polls, and burying a spend total inside it would make the
    // cheap question expensive to ask.
    CommandContribution(
      id: 'companion.usage',
      command: 'companion.usage',
      title: 'Clide: what he has spent this run',
      titleKey: 'command.usage',
      i18nNamespace: id,
      run: (_) async {
        final ledger = _ledger;
        if (ledger == null) {
          return IpcResponse.err(
            id: '',
            error: IpcError(code: 1, kind: 'inactive', message: 'the companion is not active'),
          );
        }
        final t = ledger.total;
        return IpcResponse.ok(
          id: '',
          data: {
            'turns': ledger.turns,
            'totalTokens': t.totalTokens,
            'inputTokens': t.inputTokens,
            'outputTokens': t.outputTokens,
            'thinkingTokens': t.thinkingTokens,
            'spokenTokens': t.spokenTokens,
            'cacheCreationTokens': t.cacheCreationTokens,
            'cacheReadTokens': t.cacheReadTokens,
            'costUsd': t.costUsd,
            // Named so a reader cannot mistake the figure for a bill, and
            // scoped so nobody reads it as a lifetime-across-runs total.
            'costBasis': 'api-equivalent; nothing is billed under subscription auth',
            'scope': 'this clide run',
          },
        );
      },
    ),
    CommandContribution(
      id: 'companion.ask',
      command: 'companion.ask',
      title: 'Clide: ask a question',
      titleKey: 'command.ask',
      i18nNamespace: id,
      run: (args) async {
        final question = args.join(' ').trim();
        if (question.isEmpty) {
          return IpcResponse.err(
            id: '',
            error: IpcError(code: 1, kind: 'bad-args', message: 'usage: clide companion.ask "<question>"'),
          );
        }
        final sent = _session?.ask(question) ?? false;
        // A question that went nowhere must say so rather than reporting
        // success — the caller has no other way to find out.
        if (!sent) {
          return IpcResponse.err(
            id: '',
            error: IpcError(code: 1, kind: 'no-session', message: 'Clide is not running for this workspace'),
          );
        }
        return IpcResponse.ok(id: '', data: const {'status': 'asked'});
      },
    ),
    CommandContribution(
      id: 'companion.say',
      command: 'companion.say',
      title: 'Clide: read his last remark',
      titleKey: 'command.say',
      i18nNamespace: id,
      run: (_) async => IpcResponse.ok(id: '', data: {'remark': ?lastRemark}),
    ),
    CommandContribution(
      id: 'companion.open',
      command: 'companion.open',
      title: 'Clide: open his conversation',
      titleKey: 'command.open',
      i18nNamespace: id,
      run: (_) async => _askSurface(openRequests, 'opened'),
    ),
    CommandContribution(
      id: 'companion.focus',
      command: 'companion.focus',
      title: 'Clide: focus his input',
      titleKey: 'command.focus',
      i18nNamespace: id,
      run: (_) async => _askSurface(focusRequests, 'focused'),
    ),
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
                help: 'He names how he feels on each remark and the face follows. Off, his expression comes from what his session is doing.',
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
