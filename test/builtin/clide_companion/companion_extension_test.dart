import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:clide/src/ipc/envelope.dart';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/companion_session.dart';
import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/builtin/clide_companion/src/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

class _FakeProc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();

  @override
  Stream<String> get lines => _ctl.stream;

  @override
  void writeLine(String line) {}

  @override
  Future<void> kill() async {
    if (!_ctl.isClosed) await _ctl.close();
  }
}

/// Plain `test`, not `testWidgets`: these persist settings, which is real file
/// I/O, and awaiting that inside a widget test's fake-async clock hangs.
void main() {
  // The extension loads Clide's brief off `rootBundle` (T-532), and a companion
  // without one is refused rather than launched — so without a binding these
  // tests would see "no session" and read it as a lifecycle bug.
  TestWidgetsFlutterBinding.ensureInitialized();

  late KernelFixture f;
  late ClideCompanionExtension ext;

  setUp(() async {
    f = await KernelFixture.create();
    await f.services.settings.setProjectDir(f.tempDir);
    ext = ClideCompanionExtension();
    f.services.extensions.register(ext);
    await f.services.extensions.activateAll();
  });

  tearDown(() => f.dispose());

  /// The next state announcement, with a deadline so a wiring break fails as a
  /// timeout with a name rather than hanging the suite.
  Future<Message> nextState() =>
      f.services.messages.subscribe(publisher: clideCompanionPublisher, channel: companionStateChannel).first.timeout(const Duration(seconds: 5));

  group('set requests are applied and announced', () {
    test('a disable request persists and is announced', () async {
      final announced = nextState();
      publishCompanionSet(f.services.messages, enabled: false);
      final m = await announced;

      expect(m.data['enabled'], isFalse, reason: 'the announcement must carry the applied state');
      expect(f.services.settings.get<bool>(kCompanionEnabledKey), isFalse, reason: 'and it must have been persisted, not just broadcast');
    });

    test('a minimise request touches open and leaves enabled alone', () async {
      final announced = nextState();
      publishCompanionSet(f.services.messages, open: false);
      final m = await announced;

      expect(m.data['open'], isFalse);
      expect(m.data['enabled'], isTrue, reason: 'minimising is not disabling');
      expect(f.services.settings.get<bool>(kCompanionEnabledKey), isNull, reason: 'an untouched key must stay unset, not be written with its default');
    });

    test('an unknown frequency is normalised rather than stored raw', () async {
      // Move off the default first, or the normalised value would land back on
      // it and correctly announce nothing — which would make this test pass for
      // the wrong reason.
      final toChatty = nextState();
      publishCompanionSet(f.services.messages, frequency: CompanionFrequency.chatty.name);
      expect((await toChatty).data['frequency'], CompanionFrequency.chatty.name);

      final normalised = nextState();
      publishCompanionSet(f.services.messages, frequency: 'enthusiastic');
      expect((await normalised).data['frequency'], CompanionFrequency.notable.name);
      expect(f.services.settings.get<String>(kCompanionFrequencyKey), CompanionFrequency.notable.name, reason: 'junk must never reach the settings file');
    });
  });

  group('the store is the single source of the announcement', () {
    test('a direct settings write is announced too', () async {
      // The settings panel writes the key itself; it does not know the bus
      // exists. If only `companion.set` produced announcements, toggling in
      // the panel would persist without anything on screen noticing.
      final announced = nextState();
      await f.services.settings.set(kCompanionEnabledKey, false);
      final m = await announced;
      expect(m.data['enabled'], isFalse);
    });

    test('an unrelated settings write announces nothing', () async {
      // The store notifies on every key. Republishing on each one would wake
      // every companion surface whenever any preference anywhere changed.
      var seen = 0;
      final sub = f.services.messages.subscribe(publisher: clideCompanionPublisher, channel: companionStateChannel).listen((_) => seen++);
      await f.services.settings.set('app.log.level', 'debug');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(seen, 0, reason: 'a change to someone else\'s key must not announce companion state');
    });

    test('re-requesting the current state announces nothing', () async {
      await f.services.settings.set(kCompanionEnabledKey, false);
      var seen = 0;
      final sub = f.services.messages.subscribe(publisher: clideCompanionPublisher, channel: companionStateChannel).listen((_) => seen++);
      publishCompanionSet(f.services.messages, enabled: false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(seen, 0, reason: 'a no-op set must not produce a state change');
    });
  });

  group('the kill switch reaches the process (T-545)', () {
    /// A workspace has to be open for a companion to exist at all, and the
    /// orchestrator has to be the fake one — these tests are about wiring, not
    /// about launching `claude`.
    Future<void> openWorkspace() async {
      final repo = Directory('${f.tempDir.path}/repo');
      await Directory('${repo.path}/.git').create(recursive: true);
      await f.services.project.open(repo.path);
    }

    setUp(() async {
      activeSessionOrchestrator = ClaudeSessionOrchestrator(processFactory: ({required sessionArgs, required cwd, env}) async => _FakeProc());
      await openWorkspace();
    });

    tearDown(() => activeSessionOrchestrator = null);

    ManagedSession? companion() => activeSessionOrchestrator?.byId(kCompanionSessionId);

    test('opening a workspace with the companion enabled starts a session', () async {
      await pumpEventQueue();
      expect(companion(), isNotNull, reason: 'the default is enabled, so a workspace should have a companion');
    });

    test('flipping the preference off kills the running process', () async {
      await pumpEventQueue();
      expect(companion(), isNotNull);

      await f.services.settings.set(kCompanionEnabledKey, false);
      await pumpEventQueue();

      expect(companion(), isNull, reason: 'the switch must re-check on change, not only at spawn');
    });

    test('minimising leaves the process alone', () async {
      await pumpEventQueue();
      final before = companion();

      await f.services.settings.set(kCompanionOpenKey, false);
      await pumpEventQueue();

      expect(identical(companion(), before), isTrue, reason: 'closing the strip pauses ingest; it does not spend the session');
      expect(ext.sessionController!.ingesting, isFalse);
    });

    test('deactivating tears the session down', () async {
      await pumpEventQueue();
      expect(companion(), isNotNull);

      await f.services.extensions.deactivate(ext.id);

      expect(companion(), isNull, reason: 'a process that outlives its extension outlives its off switch');
    });

    test('a language change re-composes his brief (T-558)', () async {
      // His brief is a locale-routed document and the prompt is argv, so a
      // language change cannot be applied to a running process — the sync path
      // has to run again and hand the controller a new one.
      //
      // The trigger is I18n's own notification, NOT the `app.locale` setting.
      // Both fire, but `root_shell` reacts to that same store to call
      // setLocale: with our listener first we would compose from the locale on
      // its way out and conclude nothing had changed. I18n notifies once, after
      // the catalogs are loaded, which is the only moment the new locale is
      // true. Asserted here as "a settings write did not do it" — the locale is
      // never written in this test.
      await pumpEventQueue();
      expect(companion(), isNotNull);

      await f.services.i18n.setLocale(const Locale('nl', 'NL'));
      await pumpEventQueue();

      // Only `en_us/clide-brief.md` is bundled, so nl_NL falls back to it and
      // the composed prompt is byte-identical. That must NOT restart him: a
      // locale with no brief of its own is not a language change as far as
      // Clide is concerned, and throwing away his conversation for a prompt
      // that did not move is the failure this compare exists to prevent.
      expect(companion(), isNotNull, reason: 'an identical brief must not cost him his conversation');
      expect(ext.sessionController!.running, isTrue);
    });
  });

  group('a language change reaches him (T-558)', () {
    // Both tests count trips through `_syncSession`. With no workspace open,
    // resolving the root falls through to `files.root` over IPC — so stubbing
    // it turns "did the sync path run" into something countable. An empty path
    // answers "no workspace", which keeps this process-free: nothing spawns,
    // and the count is the only effect.

    test('it follows i18n rather than the app.locale setting', () async {
      // Both notifications exist. The settings one races: `root_shell` reacts
      // to that same store to call setLocale, so if our listener ran first we
      // would compose the brief from the locale on its way out and conclude
      // nothing had changed. I18n notifies once, after the catalogs are loaded,
      // which is the only moment the new locale is actually true.
      //
      // The locale is never written to settings here, so a settings listener
      // could not have produced this.
      var calls = 0;
      f.ipc.stub('files.root', (_) async {
        calls++;
        return IpcResponse.ok(id: '', data: const {'path': ''});
      });
      await pumpEventQueue();
      calls = 0;

      await f.services.i18n.setLocale(const Locale('nl', 'NL'));
      await pumpEventQueue();

      expect(calls, greaterThan(0), reason: 'a language change must re-run the sync path — the brief is fixed at spawn');
    });

    test('and stops when the extension does', () async {
      var calls = 0;
      f.ipc.stub('files.root', (_) async {
        calls++;
        return IpcResponse.ok(id: '', data: const {'path': ''});
      });
      await f.services.extensions.deactivate(ext.id);
      await pumpEventQueue();
      calls = 0;

      await f.services.i18n.setLocale(const Locale('nl', 'NL'));
      await pumpEventQueue();

      expect(calls, 0, reason: 'a listener that outlives its extension is a leak that spawns processes');
    });
  });

  group('lifecycle', () {
    test('deactivating stops it listening', () async {
      await f.services.extensions.deactivate(ext.id);
      var seen = 0;
      final sub = f.services.messages.subscribe(publisher: clideCompanionPublisher, channel: companionStateChannel).listen((_) => seen++);
      publishCompanionSet(f.services.messages, enabled: false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(seen, 0);
      expect(f.services.settings.get<bool>(kCompanionEnabledKey), isNull, reason: 'a deactivated extension must not still be writing preferences');
    });
  });

  group('the settings surface', () {
    test('contributes a category whose fields are the documented keys', () async {
      final category = f.services.settingsRegistry.categories.firstWhere((c) => c.id == 'clide-companion');
      final keys = [
        for (final s in category.sections)
          for (final field in s.fields) field.key,
      ];
      expect(keys, contains(kCompanionEnabledKey));
      expect(keys, contains(kCompanionFrequencyKey));
      expect(keys, contains(kCompanionSuspendWhenMinimisedKey));
    });

    test('every field carries an i18n key and the category names its namespace', () {
      // D-21/D-102: labels resolve through the catalog; the inline English is
      // the fallback, not the source.
      final category = f.services.settingsRegistry.categories.firstWhere((c) => c.id == 'clide-companion');
      expect(category.i18nNamespace, 'builtin.clide-companion');
      expect(category.titleKey, isNotNull);
      for (final section in category.sections) {
        expect(section.labelKey, isNotNull, reason: '${section.label} has no key');
        for (final field in section.fields) {
          expect(field.labelKey, isNotNull, reason: '${field.key} label has no key');
          if (field.help != null) expect(field.helpKey, isNotNull, reason: '${field.key} help has no key');
          for (final o in field.options) {
            expect(o.labelKey, isNotNull, reason: '${field.key} option ${o.value} has no key');
          }
        }
      }
    });

    test('the toggle default matches the code default', () {
      // Reset-to-default in the panel restores `defaultValue`; if that differed
      // from what an unset key reads as, resetting would change behaviour.
      final category = f.services.settingsRegistry.categories.firstWhere((c) => c.id == 'clide-companion');
      final enabled = [
        for (final s in category.sections)
          for (final field in s.fields) field,
      ].firstWhere((field) => field.key == kCompanionEnabledKey);
      expect(enabled.defaultValue, kCompanionEnabledDefault);
    });
  });
}
