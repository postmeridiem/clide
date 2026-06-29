/// Tests for `icon.show` — the CLI that drives a Phosphor glyph card into the
/// Claude conversation (T-313, D-6 parity). Verifies glyph resolution (name +
/// 0xNNNN), the --file metadata payload (label/description/color), the published
/// `icon` payload, and honest failure on unknown glyphs / colors / no UI.
library;

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/icon_commands.dart';
import 'package:test/test.dart';

void main() {
  late List<({String publisher, String channel, Map<String, Object?> data})> published;
  late DaemonDispatcher d;

  const glyphs = {'gear': 0xe2a4, 'folder': 0xe24a, 'gauge': 0xe1d0};

  void wire({bool liveUi = true, Map<String, String> files = const {}}) {
    published = [];
    d = DaemonDispatcher();
    registerIconCommands(
      d,
      () {
        if (!liveUi) return null;
        return (p, c, data) => published.add((publisher: p, channel: c, data: data));
      },
      resolve: (name) => glyphs[name],
      readFile: (path) async => files[path],
    );
  }

  Future<IpcResponse> show(List<String> positional, {Map<String, Object?>? flags}) =>
      d.dispatch(IpcRequest(id: '1', cmd: 'icon.show', args: {'positional': positional, 'flags': ?flags}));

  test('variadic positionals resolve to codepoint entries', () async {
    wire();
    final r = await show(['gear', 'folder']);
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(r.data['count'], 2);
    expect(published.single.channel, 'icon');
    expect(published.single.data['entries'], [
      {'codepoint': 0xe2a4, 'name': 'gear'},
      {'codepoint': 0xe24a, 'name': 'folder'},
    ]);
  });

  test('a 0xNNNN codepoint is accepted directly', () async {
    wire();
    final r = await show(['0xe2a4']);
    expect(r.ok, isTrue, reason: r.error?.message);
    expect((published.single.data['entries'] as List).single, {'codepoint': 0xe2a4, 'name': '0xe2a4'});
  });

  test('--file entries carry label, description, and color', () async {
    wire(files: {'i.json': '[{"icon":"gear","label":"Settings","description":"global","color":"#e2b714"}]'});
    final r = await show([], flags: {'file': 'i.json'});
    expect(r.ok, isTrue, reason: r.error?.message);
    expect((published.single.data['entries'] as List).single, {
      'codepoint': 0xe2a4,
      'name': 'gear',
      'label': 'Settings',
      'description': 'global',
      'color': '#e2b714',
    });
  });

  test('a --stdin payload is parsed like --file (T-315)', () async {
    wire();
    final r = await show([], flags: {'stdin': '[{"icon":"gear","label":"Settings"}]'});
    expect(r.ok, isTrue, reason: r.error?.message);
    expect((published.single.data['entries'] as List).single, {'codepoint': 0xe2a4, 'name': 'gear', 'label': 'Settings'});
  });

  test('--stdin wins over --file', () async {
    wire(files: {'i.json': '[{"icon":"folder"}]'});
    final r = await show([], flags: {'stdin': '[{"icon":"gear"}]'});
    expect(r.ok, isTrue, reason: r.error?.message);
    expect((published.single.data['entries'] as List).single['name'], 'gear');
  });

  test('a card-level --color rides along', () async {
    wire();
    final r = await show(['gear'], flags: {'color': 'red'});
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(published.single.data['color'], 'red');
  });

  test('an unknown glyph name is an honest userError', () async {
    wire();
    final r = await show(['notaglyph']);
    expect(r.error?.kind, IpcErrorKind.userError);
    expect(published, isEmpty);
  });

  test('an invalid color is an honest userError', () async {
    wire(files: {'i.json': '[{"icon":"gear","color":"notacolor"}]'});
    final r = await show([], flags: {'file': 'i.json'});
    expect(r.error?.kind, IpcErrorKind.userError);
  });

  test('a malformed --file is a userError', () async {
    wire(files: {'i.json': 'not json'});
    final r = await show([], flags: {'file': 'i.json'});
    expect(r.error?.kind, IpcErrorKind.userError);
  });

  test('no icons at all is a userError', () async {
    wire();
    final r = await show([]);
    expect(r.error?.kind, IpcErrorKind.userError);
  });

  test('no live UI is a toolError, not a hang', () async {
    wire(liveUi: false);
    final r = await show(['gear']);
    expect(r.error?.kind, IpcErrorKind.toolError);
  });
}
