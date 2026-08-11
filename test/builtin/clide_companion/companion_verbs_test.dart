import 'package:clide/builtin/clide_companion/src/extension.dart';
import 'package:clide/extension/extension.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

/// T-567 — D-6 parity for talking to Clide, and the a11y contract that goes
/// with it (D-20).
///
/// The strip is not a slot, so none of this comes free; D-107 accepts that its
/// parity is hand-rolled. These assert the verbs exist, do the right thing, and
/// **fail honestly** — a question that reached nobody must say so, because the
/// caller has no other way to find out.
void main() {
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

  CommandContribution verb(String command) => ext.contributions.whereType<CommandContribution>().firstWhere((c) => c.command == command);

  group('every UI action has a verb', () {
    test('asking, reading, opening and focusing are all addressable', () {
      final commands = ext.contributions.whereType<CommandContribution>().map((c) => c.command).toSet();
      expect(commands, containsAll(['companion.ask', 'companion.say', 'companion.open', 'companion.focus']));
    });

    test('so is the strip itself — rail button, kill switch, frequency (T-529)', () {
      // Verified against a live instance before this landed: 79 verbs and not
      // one of them touched the companion.
      final commands = ext.contributions.whereType<CommandContribution>().map((c) => c.command).toSet();
      expect(commands, containsAll(['companion.show', 'companion.hide', 'companion.enable', 'companion.disable', 'companion.frequency', 'companion.status']));
    });

    test('each carries an i18n key, so the palette is translatable', () {
      // D-21/D-102: the inline English is the fallback, not the source.
      for (final c in ext.contributions.whereType<CommandContribution>()) {
        expect(c.titleKey, isNotNull, reason: '${c.command} has no title key');
        expect(c.i18nNamespace, ext.id, reason: '${c.command} names the wrong namespace');
      }
    });
  });

  group('the strip', () {
    test('status reports what the user asked for and what is true, separately', () async {
      // Enabled is intent; running is fact. They differ while a spawn is in
      // flight and whenever there is no workspace, and conflating them would
      // cheerfully report a companion that is not there.
      final r = await verb('companion.status').run([]);
      expect(r.data.keys, containsAll(['enabled', 'open', 'frequency', 'running']));
      expect(r.data['running'], isFalse, reason: 'no workspace in this fixture');
    });

    test('hiding drives the same path the rail button does', () async {
      // Published as companion.set, so the extension applies, persists and
      // announces it from one place — the CLI cannot reach a state the UI
      // would disagree with.
      final announced = f.services.messages.subscribe(publisher: 'clide.companion', channel: 'companion.state').first;
      await verb('companion.hide').run([]);

      expect((await announced).data['open'], isFalse);
      expect(f.services.settings.get<bool>('project.companion.open'), isFalse);
    });

    test('show and hide are a pair, not a toggle', () async {
      // A toggle cannot be made idempotent, so a script has no way to ensure a
      // state — which is most of what a verb is for.
      await verb('companion.hide').run([]);
      await verb('companion.hide').run([]);
      expect(f.services.settings.get<bool>('project.companion.open'), isFalse);

      await verb('companion.show').run([]);
      expect(f.services.settings.get<bool>('project.companion.open'), isTrue);
    });

    test('disabling persists the kill switch', () async {
      // Awaits the announcement rather than reading straight after the call:
      // the verb publishes, and the extension persists on the far side of the
      // bus, so the write has not happened when `run` returns.
      final announced = f.services.messages.subscribe(publisher: 'clide.companion', channel: 'companion.state').first;
      await verb('companion.disable').run([]);
      await announced;

      expect(f.services.settings.get<bool>('project.companion.enabled'), isFalse);
    });

    test('frequency with no argument reports rather than sets', () async {
      final r = await verb('companion.frequency').run([]);
      expect(r.data['frequency'], 'notable');
    });

    test('a typo is refused rather than silently becoming the default', () async {
      // CompanionFrequency.parse falls back to `notable` for junk, which is
      // right when reading a stored value and wrong for a command.
      final r = await verb('companion.frequency').run(['enthusiastic']);
      expect(r.ok, isFalse);
      expect(r.error!.kind, 'bad-args');
      expect(f.services.settings.get<String>('project.companion.frequency'), isNull, reason: 'nothing should have been written');
    });

    test('a valid level is applied', () async {
      final announced = f.services.messages.subscribe(publisher: 'clide.companion', channel: 'companion.state').first;
      await verb('companion.frequency').run(['chatty']);
      await announced;

      expect(f.services.settings.get<String>('project.companion.frequency'), 'chatty');
    });
  });

  group('asking', () {
    test('an empty question is refused rather than sent', () async {
      final r = await verb('companion.ask').run([]);
      expect(r.ok, isFalse);
      expect(r.error!.kind, 'bad-args');
    });

    test('with no session it fails loudly instead of reporting success', () async {
      // The caller has no other way to discover the question went nowhere.
      final r = await verb('companion.ask').run(['what', 'did', 'that', 'mean?']);
      expect(r.ok, isFalse);
      expect(r.error!.kind, 'no-session');
    });
  });

  group('reading him is a pull, never a push', () {
    test('his last remark is readable on request', () async {
      ext.lastRemark = 'Those accumulate.';
      final r = await verb('companion.say').run([]);
      expect(r.data['remark'], 'Those accumulate.');
    });

    test('nothing said yet is an absent key, not an empty string', () {
      // Absent is honest. An empty string is a value a caller would render.
      expect(ext.lastRemark, isNull);
    });
  });

  group('the surface is asked, not reached into', () {
    test('opening bumps a counter the strip listens to', () async {
      final before = ext.openRequests.value;
      await verb('companion.open').run([]);
      expect(ext.openRequests.value, before + 1);
    });

    test('two opens are two events, not one', () async {
      // A bool would swallow the second, and "open it again" is a real thing to
      // want after dismissing by accident.
      final before = ext.openRequests.value;
      await verb('companion.open').run([]);
      await verb('companion.open').run([]);
      expect(ext.openRequests.value, before + 2);
    });

    test('focusing bumps its own', () async {
      final before = ext.focusRequests.value;
      await verb('companion.focus').run([]);
      expect(ext.focusRequests.value, before + 1);
    });
  });
}
