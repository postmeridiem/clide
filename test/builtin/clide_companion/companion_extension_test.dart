import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/builtin/clide_companion/src/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

/// Plain `test`, not `testWidgets`: these persist settings, which is real file
/// I/O, and awaiting that inside a widget test's fake-async clock hangs.
void main() {
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
