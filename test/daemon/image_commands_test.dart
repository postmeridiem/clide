/// Tests for `image.show` — the CLI that drives an image card into the Claude
/// conversation log (T-249, D-6 parity). Verifies format validation, path
/// resolution, the published MessageBus 'image' payload, and honest failure
/// when the file is missing or there is no live UI.
library;

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/image_commands.dart';
import 'package:test/test.dart';

void main() {
  late List<({String publisher, String channel, Map<String, Object?> data})> published;
  late DaemonDispatcher d;

  // [found] is the set of paths the fake resolver treats as existing on disk;
  // it echoes them back prefixed with /abs to stand in for an absolute path.
  void wire({bool liveUi = true, Set<String> found = const {'docs/diagram.png'}, bool withResolver = true}) {
    published = [];
    d = DaemonDispatcher();
    registerImageCommands(
      d,
      () {
        if (!liveUi) return null;
        return (publisher, channel, data) => published.add((publisher: publisher, channel: channel, data: data));
      },
      resolve: withResolver ? (path) => found.contains(path) ? '/abs/$path' : null : null,
    );
  }

  Future<IpcResponse> show(List<String> positional, {Map<String, Object?>? flags}) => d.dispatch(
        IpcRequest(id: '1', cmd: 'image.show', args: {'positional': positional, if (flags != null) 'flags': flags}),
      );

  test('resolves a workspace-relative path and publishes an image message', () async {
    wire();
    final r = await show(['docs/diagram.png']);
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(r.data['shown'], isTrue);
    expect(r.data['path'], '/abs/docs/diagram.png');
    expect(published.single.publisher, 'cli');
    expect(published.single.channel, 'image');
    expect(published.single.data, {'path': '/abs/docs/diagram.png'});
  });

  test('--caption rides along in the payload', () async {
    wire();
    final r = await show(['docs/diagram.png'], flags: {'caption': 'before the fix'});
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(published.single.data, {'path': '/abs/docs/diagram.png', 'caption': 'before the fix'});
  });

  test('--fullscreen rides along in the payload (T-252)', () async {
    wire();
    final r = await show(['docs/diagram.png'], flags: {'fullscreen': true});
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(r.data['fullscreen'], isTrue);
    expect(published.single.data, {'path': '/abs/docs/diagram.png', 'fullscreen': true});
  });

  test('accepts the documented formats case-insensitively', () async {
    for (final name in ['a.PNG', 'b.jpg', 'c.jpeg', 'd.gif', 'e.webp', 'f.bmp']) {
      wire(found: {name});
      final r = await show([name]);
      expect(r.ok, isTrue, reason: '$name: ${r.error?.message}');
    }
  });

  test('unsupported format → userError, nothing published', () async {
    wire(found: {'notes.txt'});
    final r = await show(['notes.txt']);
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.userError);
    expect(published, isEmpty);
  });

  test('missing path → userError', () async {
    wire();
    final r = await show([]);
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.userError);
    expect(published, isEmpty);
  });

  test('a file that does not resolve → notFound, nothing published', () async {
    wire(found: const {});
    final r = await show(['docs/diagram.png']);
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.notFound);
    expect(published, isEmpty);
  });

  test('no live UI (null publisher) → toolError, not a hang', () async {
    wire(liveUi: false);
    final r = await show(['docs/diagram.png']);
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.toolError);
  });

  test('a leading-dash path is rejected by the schema (argv-injection guard)', () async {
    wire();
    final r = await show(['-rf.png']);
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.userError);
    expect(published, isEmpty);
  });

  test('null resolver passes the path through unverified (headless)', () async {
    wire(withResolver: false);
    final r = await show(['docs/diagram.png']);
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(published.single.data, {'path': 'docs/diagram.png'});
  });

  test('image.show appears in the capabilities discovery surface (T-248)', () async {
    wire();
    final r = await d.dispatch(IpcRequest(id: '1', cmd: 'capabilities', args: const {}));
    expect(r.ok, isTrue);
    final commands = r.data['commands'] as Map<String, Object?>;
    expect(commands.containsKey('image.show'), isTrue);
    final spec = commands['image.show'] as Map<String, Object?>;
    expect(spec['subsystem'], 'image');
    expect(spec['verb'], 'show');
    expect(spec['positional'], ['path']);
    final args = spec['args'] as Map<String, Object?>;
    expect((args['path'] as Map)['required'], true);
    expect(args.containsKey('caption'), isTrue);
  });
}
