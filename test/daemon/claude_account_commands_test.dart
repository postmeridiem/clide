/// Tests for `claude account …` (T-480, epic T-476; D-6 CLI parity). Verifies
/// each verb's registry effect, the published action payloads, and honest
/// userErrors — against a fake AccountStore so the handler stays Flutter-free
/// (runs under `dart test`).
library;

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/claude_account_commands.dart';
import 'package:test/test.dart';

class _FakeStore implements AccountStore {
  final _accounts = <({String name, String dir})>[];
  final _bindings = <String, String>{}; // cwd → account name
  List<String> detected = const [];

  @override
  List<({String name, String dir})> get accounts => List.of(_accounts);
  @override
  String? boundAccountName(String cwd) => _bindings[cwd];
  @override
  Set<String> boundAccountNames() => _bindings.values.toSet();
  @override
  String defaultDirFor(String name) => '/home/u/.claude-$name';
  @override
  List<String> detectedDirs() => detected;
  @override
  Future<void> add(String name, String dir) async => _accounts.add((name: name, dir: dir));
  @override
  Future<void> remove(String name) async => _accounts.removeWhere((a) => a.name == name);
  @override
  Future<void> bind(String cwd, String name) async => _bindings[cwd] = name;
  @override
  Future<void> unbind(String cwd) async => _bindings.remove(cwd);
}

void main() {
  late _FakeStore store;
  late List<({String publisher, String channel, Map<String, Object?> data})> published;
  late DaemonDispatcher d;

  void wire({String? cwd = '/repo', bool withStore = true}) {
    store = _FakeStore();
    published = [];
    d = DaemonDispatcher();
    registerClaudeAccountCommands(
      d,
      () => withStore ? store : null,
      publisher: () =>
          (p, c, data) => published.add((publisher: p, channel: c, data: data)),
      workspaceCwd: () => cwd,
    );
  }

  Future<IpcResponse> run(List<String> positional, {Map<String, Object?>? flags}) =>
      d.dispatch(IpcRequest(id: '1', cmd: 'claude.account', args: {'positional': positional, 'flags': ?flags}));

  test('registered on the dispatcher → shows in capabilities (T-480 #1)', () async {
    wire();
    final caps = await d.dispatch(IpcRequest(id: 'c', cmd: 'capabilities', args: const {}));
    expect((caps.data['commands'] as Map).containsKey('claude.account'), isTrue);
  });

  group('add', () {
    test('registers with the default dir, then is idempotent, then conflicts', () async {
      wire();
      var r = await run(['add', 'work']);
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data, {'name': 'work', 'dir': '/home/u/.claude-work', 'created': true});

      r = await run(['add', 'work']); // same args → no-op
      expect(r.data['created'], isFalse);

      r = await run(['add', 'work'], flags: {'dir': '/other'}); // conflicting dir
      expect(r.ok, isFalse);
      expect(r.error?.message, contains('already exists'));
    });

    test('--dir uses the explicit path; missing name errors', () async {
      wire();
      expect((await run(['add', 'work'], flags: {'dir': '/custom'})).data['dir'], '/custom');
      expect((await run(['add'])).ok, isFalse);
    });
  });

  test('list returns accounts + this workspace binding + detected dirs', () async {
    wire();
    store.detected = ['/home/u/.claude-old'];
    await run(['add', 'work']);
    await run(['set', 'work']);
    final r = await run(['list']);
    expect(r.data['accounts'], [
      {'name': 'work', 'dir': '/home/u/.claude-work'},
    ]);
    expect(r.data['boundAccount'], 'work');
    expect(r.data['detected'], ['/home/u/.claude-old']);
  });

  test('set binds + publishes; unknown account errors', () async {
    wire();
    expect((await run(['set', 'nope'])).ok, isFalse);
    await run(['add', 'work']);
    final r = await run(['set', 'work']);
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(store.boundAccountName('/repo'), 'work');
    expect(published.single.channel, accountActionChannel);
    expect(published.single.data, {'action': 'set', 'name': 'work', 'cwd': '/repo'});
  });

  test('unset clears the binding + publishes the previous account', () async {
    wire();
    await run(['add', 'work']);
    await run(['set', 'work']);
    published.clear();
    final r = await run(['unset']);
    expect(r.ok, isTrue);
    expect(store.boundAccountName('/repo'), isNull);
    expect(published.single.data, {'action': 'unset', 'cwd': '/repo', 'previous': 'work'});
  });

  test('remove refuses while bound, succeeds once unset; --purge publishes', () async {
    wire();
    await run(['add', 'work']);
    await run(['set', 'work']);
    expect((await run(['remove', 'work'])).ok, isFalse, reason: 'bound → refused');
    await run(['unset']);
    published.clear();
    final r = await run(['remove', 'work'], flags: {'purge': true});
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(store.accounts, isEmpty);
    expect(published.single.data, {'action': 'purge', 'name': 'work'});
  });

  test('login publishes a login action with the dir; unknown account errors', () async {
    wire();
    expect((await run(['login', 'work'])).ok, isFalse);
    await run(['add', 'work']);
    published.clear();
    final r = await run(['login', 'work']);
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(published.single.data, {'action': 'login', 'name': 'work', 'dir': '/home/u/.claude-work'});
  });

  test('unknown action → userError listing the verbs', () async {
    wire();
    final r = await run(['frobnicate']);
    expect(r.ok, isFalse);
    expect(r.error?.message, contains('unknown account action'));
  });

  test('degrades to a clear error when no registry is wired', () async {
    wire(withStore: false);
    final r = await run(['list']);
    expect(r.ok, isFalse);
    expect(r.error?.message, contains('unavailable'));
  });
}
