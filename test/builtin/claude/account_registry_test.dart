/// T-483: AccountRegistry — user-scope storage + typed reader/writer for the
/// per-repo Claude account epic (T-476). Persistence flows through a real
/// SettingsStore over a temp appDir, so these cover the round-trip (incl. a
/// reload from disk) without mocking the store.
library;

import 'dart:io';

import 'package:clide/builtin/claude/src/account_registry.dart';
import 'package:clide/kernel/src/settings.dart';
import 'package:clide/src/ipc/paths.dart' show canonicalWorkspaceKey, fnv1a64Hex;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory appDir;
  late SettingsStore store;
  late AccountRegistry reg;

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('clide-accounts-');
    store = SettingsStore(appDir: appDir);
    await store.load();
    reg = AccountRegistry(store);
  });
  tearDown(() {
    store.dispose();
    if (appDir.existsSync()) appDir.deleteSync(recursive: true);
  });

  group('account registry CRUD', () {
    test('register + read back; replace by name; remove', () async {
      expect(reg.accounts, isEmpty);
      await reg.registerAccount('personal', '/home/u/.claude-personal');
      await reg.registerAccount('work', '/home/u/.claude-work');
      expect(reg.accounts, [const Account(name: 'personal', dir: '/home/u/.claude-personal'), const Account(name: 'work', dir: '/home/u/.claude-work')]);
      expect(reg.accountByName('work')?.dir, '/home/u/.claude-work');
      expect(reg.accountByName('nope'), isNull);

      // Re-register by the same name replaces (no duplicate).
      await reg.registerAccount('personal', '/home/u/.claude-personal2');
      expect(reg.accounts.where((a) => a.name == 'personal'), hasLength(1));
      expect(reg.accountByName('personal')?.dir, '/home/u/.claude-personal2');

      await reg.removeAccount('personal');
      expect(reg.accountByName('personal'), isNull);
      expect(reg.accounts, hasLength(1));
    });

    test('the accounts list survives a reload from disk', () async {
      await reg.registerAccount('work', '/home/u/.claude-work');
      // Fresh store over the same appDir, loaded from the YAML on disk.
      final store2 = SettingsStore(appDir: appDir);
      await store2.load();
      addTearDown(store2.dispose);
      final reg2 = AccountRegistry(store2);
      expect(reg2.accounts, [const Account(name: 'work', dir: '/home/u/.claude-work')]);
    });
  });

  group('workspace binding', () {
    test('bind resolves an account; unbind clears it; unknown name → null', () async {
      await reg.registerAccount('work', '/home/u/.claude-work');
      expect(reg.accountForWorkspace('/repo/a'), isNull);

      await reg.bindWorkspace('/repo/a', 'work');
      expect(reg.accountForWorkspace('/repo/a')?.dir, '/home/u/.claude-work');

      // A binding to a removed account degrades to null (Claude default).
      await reg.removeAccount('work');
      expect(reg.accountForWorkspace('/repo/a'), isNull);

      await reg.registerAccount('work', '/home/u/.claude-work');
      expect(reg.accountForWorkspace('/repo/a')?.dir, '/home/u/.claude-work');
      await reg.unbindWorkspace('/repo/a');
      expect(reg.accountForWorkspace('/repo/a'), isNull);
    });

    test('workspace hash is the D-70 socket hash and ignores trailing slashes', () {
      expect(AccountRegistry.workspaceHash('/repo/a'), AccountRegistry.workspaceHash('/repo/a/'));
      expect(AccountRegistry.workspaceHash('/repo/a'), AccountRegistry.workspaceHash('/repo/a///'));
      expect(AccountRegistry.workspaceHash('/repo/a'), isNot(AccountRegistry.workspaceHash('/repo/b')));
      // Same algorithm/input as the socket path (single source of truth, D-70).
      expect(AccountRegistry.workspaceHash('/repo/a'), fnv1a64Hex(canonicalWorkspaceKey('/repo/a')));
      // The binding key is namespaced under app.claude.account.<hash>.
      expect(AccountRegistry.bindingKey('/repo/a'), 'app.claude.account.${AccountRegistry.workspaceHash('/repo/a')}');
    });

    test('two workspaces bind independently', () async {
      await reg.registerAccount('personal', '/p');
      await reg.registerAccount('work', '/w');
      await reg.bindWorkspace('/repo/a', 'personal');
      await reg.bindWorkspace('/repo/b', 'work');
      expect(reg.accountForWorkspace('/repo/a')?.name, 'personal');
      expect(reg.accountForWorkspace('/repo/b')?.name, 'work');
    });

    test('boundName is the raw binding (survives account removal); boundAccountNames lists in-use names', () async {
      await reg.registerAccount('personal', '/p');
      await reg.registerAccount('work', '/w');
      expect(reg.boundName('/repo/a'), isNull);
      expect(reg.boundAccountNames(), isEmpty);

      await reg.bindWorkspace('/repo/a', 'personal');
      await reg.bindWorkspace('/repo/b', 'work');
      expect(reg.boundName('/repo/a'), 'personal');
      expect(reg.boundAccountNames(), {'personal', 'work'});

      // Removing the account leaves the raw binding; only resolution degrades.
      await reg.removeAccount('personal');
      expect(reg.boundName('/repo/a'), 'personal');
      expect(reg.accountForWorkspace('/repo/a'), isNull);
    });
  });

  group('bootstrap probe', () {
    test('returns ~/.claude-* dirs that look like config dirs, skipping the rest', () async {
      final home = await Directory.systemTemp.createTemp('clide-home-');
      addTearDown(() => home.deleteSync(recursive: true));
      // A config dir marked by .claude.json.
      Directory('${home.path}/.claude-personal').createSync();
      File('${home.path}/.claude-personal/.claude.json').writeAsStringSync('{}');
      // A config dir marked by sessions/.
      Directory('${home.path}/.claude-work/sessions').createSync(recursive: true);
      // A .claude-* dir that is NOT a config dir (no marker) — skipped.
      Directory('${home.path}/.claude-empty').createSync();
      // The real ~/.claude (no `-suffix`) — not a candidate.
      Directory('${home.path}/.claude').createSync();
      // An unrelated dir — skipped.
      Directory('${home.path}/projects').createSync();

      final found = probeExistingAccountDirs(home.path);
      expect(found.map((d) => d.name), ['personal', 'work']);
      expect(found.first.dir, '${home.path}/.claude-personal');
    });

    test('missing home returns empty, mutates nothing', () {
      expect(probeExistingAccountDirs('/no/such/home/${DateTime.now().microsecondsSinceEpoch}'), isEmpty);
    });
  });

  group('value types', () {
    test('Account + DetectedAccount value equality, hashCode, toString', () {
      expect(const Account(name: 'a', dir: '/d'), const Account(name: 'a', dir: '/d'));
      expect(const Account(name: 'a', dir: '/d'), isNot(const Account(name: 'a', dir: '/e')));
      expect(const Account(name: 'a', dir: '/d'), isNot('a'));
      expect(const Account(name: 'a', dir: '/d').hashCode, const Account(name: 'a', dir: '/d').hashCode);
      expect(const Account(name: 'a', dir: '/d').toString(), contains('a'));
      expect(const Account(name: 'a', dir: '/d').toJson(), {'name': 'a', 'dir': '/d'});

      expect(const DetectedAccount(name: 'a', dir: '/d'), const DetectedAccount(name: 'a', dir: '/d'));
      expect(const DetectedAccount(name: 'a', dir: '/d'), isNot(const DetectedAccount(name: 'b', dir: '/d')));
      expect(const DetectedAccount(name: 'a', dir: '/d'), isNot('a'));
      expect(const DetectedAccount(name: 'a', dir: '/d').hashCode, const DetectedAccount(name: 'a', dir: '/d').hashCode);
    });
  });

  group('sign-in probe (T-482)', () {
    test('true with a .credentials.json or an oauthAccount marker; false otherwise', () async {
      final home = await Directory.systemTemp.createTemp('clide-signin-');
      addTearDown(() => home.deleteSync(recursive: true));

      // .credentials.json present → signed in.
      final a = Directory('${home.path}/.claude-a')..createSync();
      File('${a.path}/.credentials.json').writeAsStringSync('{}');
      expect(accountIsSignedIn(a.path), isTrue);

      // .claude.json with an oauthAccount marker → signed in.
      final b = Directory('${home.path}/.claude-b')..createSync();
      File('${b.path}/.claude.json').writeAsStringSync('{"oauthAccount": {"email": "x@y.z"}}');
      expect(accountIsSignedIn(b.path), isTrue);

      // .claude.json without the marker → not signed in.
      final c = Directory('${home.path}/.claude-c')..createSync();
      File('${c.path}/.claude.json').writeAsStringSync('{"theme": "dark"}');
      expect(accountIsSignedIn(c.path), isFalse);

      // No config dir at all → not signed in.
      expect(accountIsSignedIn('${home.path}/.claude-missing'), isFalse);
    });
  });

  group('purge guard (T-480)', () {
    const home = '/home/u';
    test('accepts ~/.claude-* direct children only, rejects everything else', () {
      expect(isPurgeableAccountDir('/home/u/.claude-work', home), isTrue);
      expect(isPurgeableAccountDir('/home/u/.claude', home), isFalse); // the real config dir
      expect(isPurgeableAccountDir('/home/u/projects', home), isFalse); // not .claude-*
      expect(isPurgeableAccountDir('/home/u/sub/.claude-work', home), isFalse); // nested, not a direct child
      expect(isPurgeableAccountDir('/etc/.claude-work', home), isFalse); // elsewhere on disk
      expect(isPurgeableAccountDir('/home/u/.claude-work', ''), isFalse); // no home → never delete
    });
  });
}
