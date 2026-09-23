/// T-589 / D-114: the remembered secondary sessions round-trip through app
/// settings, per workspace, and survive bad data without throwing.
library;

import 'package:clide/builtin/claude/src/session_restore.dart';
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
