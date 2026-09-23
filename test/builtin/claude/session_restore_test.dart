/// T-589 / D-114: the remembered secondary sessions round-trip through app
/// settings, per workspace, and survive bad data without throwing.
library;

import 'package:clide/builtin/claude/src/session_restore.dart';
import 'package:clide/kernel/kernel.dart' show SettingsStore;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  test('saves per workspace, in order, and keeps only resumable sessions', () async {
    final store = SecondarySessionStore(f.services.settings, transcriptExists: (_, id) => id != 'gone');
    await store.save('/repo-a', ['one', 'gone', 'two']);
    await store.save('/repo-b', ['three']);
    expect(store.restorable('/repo-a'), ['one', 'two']);
    expect(store.restorable('/repo-b'), ['three']);
    expect(store.restorable('/repo-c'), isEmpty);
  });

  test('keys are app scope and never carry the path itself', () {
    final key = SecondarySessionStore.keyFor('/home/u/secret-project');
    expect(key, startsWith('app.session.claude.'));
    expect(key, isNot(contains('secret')));
  });

  test('the list survives a restart — read back from the settings file', () async {
    final store = SecondarySessionStore(f.services.settings, transcriptExists: (_, _) => true);
    await store.save('/repo-a', ['11111111-1111-4111-8111-111111111111', 'two']);
    final reloaded = SettingsStore(appDir: f.services.settings.appDir);
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(SecondarySessionStore(reloaded, transcriptExists: (_, _) => true).restorable('/repo-a'), ['11111111-1111-4111-8111-111111111111', 'two']);
  });

  test('a list 2.18.x wrote unquoted (it reloads as a YAML sequence) still restores', () async {
    await f.services.settings.set<List<Object?>>(SecondarySessionStore.keyFor('/r'), ['a', 'b']);
    expect(SecondarySessionStore(f.services.settings, transcriptExists: (_, _) => true).restorable('/r'), ['a', 'b']);
  });

  test('garbage in the setting reads as nothing remembered', () async {
    final store = SecondarySessionStore(f.services.settings, transcriptExists: (_, _) => true);
    await f.services.settings.set<String>(SecondarySessionStore.keyFor('/r'), 'not json');
    expect(store.restorable('/r'), isEmpty);
    await f.services.settings.set<String>(SecondarySessionStore.keyFor('/r'), '{"a":1}');
    expect(store.restorable('/r'), isEmpty);
    await f.services.settings.set<String>(SecondarySessionStore.keyFor('/r'), '["ok", 3, ""]');
    expect(store.restorable('/r'), ['ok']);
  });
}
