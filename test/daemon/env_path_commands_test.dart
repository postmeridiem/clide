/// Tests for `env path …` (D-106, T-511; D-6 CLI parity). Verifies each verb's
/// store effect, the published mutation payloads, the capture diff, and honest
/// userErrors — against a fake PathPresetStore so the handler stays
/// Flutter-free (runs under `dart test`).
library;

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/env_path_commands.dart';
import 'package:test/test.dart';

class _FakeStore implements PathPresetStore {
  final Map<String, List<String>> byCwd = {};

  @override
  List<String> dirsFor(String cwd) => List.of(byCwd[cwd] ?? const []);

  @override
  Future<void> setFor(String cwd, List<String> dirs) async {
    if (dirs.isEmpty) {
      byCwd.remove(cwd);
    } else {
      byCwd[cwd] = List.of(dirs);
    }
  }
}

void main() {
  late _FakeStore store;
  late List<({String publisher, String channel, Map<String, Object?> data})> published;
  late DaemonDispatcher d;
  late Set<String> existingDirs;
  String? loginPath;
  var processPath = '/usr/bin:/bin';

  void wire({String? cwd = '/repo', bool withStore = true}) {
    store = _FakeStore();
    published = [];
    existingDirs = {};
    loginPath = null;
    processPath = '/usr/bin:/bin';
    d = DaemonDispatcher();
    registerEnvPathCommands(
      d,
      () => withStore ? store : null,
      publisher: () =>
          (p, c, data) => published.add((publisher: p, channel: c, data: data)),
      workspaceCwd: () => cwd,
      home: () => '/home/u',
      dirExists: (dir) => existingDirs.contains(dir),
      loginPath: () => loginPath,
      processPath: () => processPath,
    );
  }

  Future<IpcResponse> run(List<String> positional) => d.dispatch(IpcRequest(id: '1', cmd: 'env.path', args: {'positional': positional}));

  test('registered on the dispatcher → shows in capabilities', () async {
    wire();
    final caps = await d.dispatch(IpcRequest(id: 'c', cmd: 'capabilities', args: const {}));
    expect((caps.data['commands'] as Map).containsKey('env.path'), isTrue);
  });

  group('set', () {
    test('replaces the preset, de-duplicated, and publishes', () async {
      wire();
      existingDirs.add('/opt/go/bin');
      final r = await run(['set', '/opt/go/bin', '/x', '/opt/go/bin']);
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['dirs'], ['/opt/go/bin', '/x']);
      expect(r.data['missing'], ['/x'], reason: 'nonexistent dirs warn, never error');
      expect(store.byCwd['/repo'], ['/opt/go/bin', '/x']);
      expect(published.single.channel, envPathChannel);
      expect(published.single.data['action'], 'set');
      expect(published.single.data['dirs'], ['/opt/go/bin', '/x']);
    });

    test('expands ~/ against HOME and strips trailing slashes', () async {
      wire();
      final r = await run(['set', '~/go/bin/', '~']);
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['dirs'], ['/home/u/go/bin', '/home/u']);
    });

    test('relative paths error; empty set points at clear', () async {
      wire();
      final rel = await run(['set', 'go/bin']);
      expect(rel.ok, isFalse);
      expect(rel.error?.message, contains('not an absolute path'));
      final empty = await run(['set']);
      expect(empty.ok, isFalse);
      expect(empty.error?.hint, contains('clear'));
    });

    test('a leading-dash entry is rejected by the schema (T-104 guard)', () async {
      wire();
      final r = await d.dispatch(
        IpcRequest(
          id: '1',
          cmd: 'env.path',
          args: {
            'positional': ['set'],
            'flags': {'dirs': '--evil'},
          },
        ),
      );
      expect(r.ok, isFalse);
    });
  });

  group('add / remove / clear', () {
    test('add appends without duplicating; remove drops; clear empties the key', () async {
      wire();
      await run(['set', '/a']);
      published.clear();

      var r = await run(['add', '/b', '/a']);
      expect(r.data['dirs'], ['/a', '/b']);

      r = await run(['remove', '/a']);
      expect(r.data['dirs'], ['/b']);

      r = await run(['clear']);
      expect(r.ok, isTrue);
      expect(r.data['dirs'], isEmpty);
      expect(store.byCwd.containsKey('/repo'), isFalse, reason: 'empty preset removes the key');
      expect(published.map((p) => p.data['action']), ['add', 'remove', 'clear']);
    });

    test('add and remove require a <dir>; removing an absent entry errors', () async {
      wire();
      expect((await run(['add'])).ok, isFalse);
      expect((await run(['remove'])).ok, isFalse);
      final r = await run(['remove', '/ghost']);
      expect(r.ok, isFalse);
      expect(r.error?.message, contains('no preset entry matches'));
    });
  });

  group('list', () {
    test('returns the preset, the missing subset, and the effective PATH preview', () async {
      wire();
      existingDirs.add('/a');
      await run(['set', '/a', '/gone']);
      final r = await run(['list']);
      expect(r.data['root'], '/repo');
      expect(r.data['dirs'], ['/a', '/gone']);
      expect(r.data['missing'], ['/gone']);
      expect(r.data['effectivePath'], startsWith('/a:/gone:'), reason: 'preset prepends the resolved PATH');
    });
  });

  group('capture', () {
    test('suggests login-shell dirs the process PATH lacks, minus the preset', () async {
      wire();
      loginPath = '/brew/bin:/usr/bin:/opt/go/bin:/bin';
      await run(['set', '/brew/bin']);
      final r = await run(['capture']);
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['suggested'], ['/opt/go/bin']);
      expect(r.data['loginShellPath'], loginPath);
      expect(r.data['processPath'], '/usr/bin:/bin');
    });

    test('no login-shell probe → empty suggestions with an honest note', () async {
      wire();
      final r = await run(['capture']);
      expect(r.data['suggested'], isEmpty);
      expect(r.data['note'], contains('unavailable'));
    });
  });

  test('no workspace / no store / unknown action error clearly', () async {
    wire(cwd: null);
    expect((await run(['list'])).error?.message, contains('no workspace'));
    wire(withStore: false);
    expect((await run(['list'])).error?.message, contains('unavailable'));
    wire();
    final r = await run(['frobnicate']);
    expect(r.ok, isFalse);
    expect(r.error?.hint, contains('list | set | add | remove | clear | capture'));
  });
}
