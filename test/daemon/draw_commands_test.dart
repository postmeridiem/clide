import 'package:clide/clide.dart';
import 'package:clide/src/daemon/draw_commands.dart';
import 'package:test/test.dart';

void main() {
  late List<({String publisher, String channel, Map<String, Object?> data})> published;
  late DaemonDispatcher d;
  late DrawingRegistry registry;
  late Map<String, String> files;

  setUp(() {
    published = [];
    files = {};
    registry = DrawingRegistry();
    d = DaemonDispatcher();
  });

  void wire({bool liveUi = true}) => registerDrawCommands(
    d,
    () => liveUi ? (pub, ch, data) => published.add((publisher: pub, channel: ch, data: data)) : null,
    registry: registry,
    readFile: (p) async => files[p],
  );

  Future<IpcResponse> draw(String? file) => d.dispatch(
    IpcRequest(
      id: '1',
      cmd: 'draw',
      args: {
        'positional': const [],
        'flags': {'file': ?file},
      },
    ),
  );

  test('primitive doc: publishes the svg + captions on the draw channel', () async {
    wire();
    files['card.json'] = '{"card":{"label":"Pipeline","description":"how"},"svg":"<svg id=\\"x\\"/>"}';
    final r = await draw('card.json');
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(r.data['shown'], isTrue);
    expect(published.single.publisher, 'cli');
    expect(published.single.channel, drawShowChannel);
    expect(published.single.data['svg'], '<svg id="x"/>');
    expect(published.single.data['label'], 'Pipeline');
    expect(published.single.data['description'], 'how');
  });

  test('template doc lowers via the registry before publishing', () async {
    wire();
    registry.register('d2', (doc) async => DrawOk('<svg data-d2="${doc.fields['source']}"/>'));
    files['c.json'] = '{"template":"d2","source":"a -> b"}';
    final r = await draw('c.json');
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(published.single.data['svg'], '<svg data-d2="a -> b"/>');
    expect(r.data['template'], 'd2');
  });

  test('a .d2 file is wrapped as a d2 template and lowered (T-494)', () async {
    wire();
    registry.register('d2', (doc) async => DrawOk('<svg data-d2="${doc.fields['source']}"/>'));
    files['pipeline.d2'] = 'a -> b';
    final r = await draw('pipeline.d2');
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(published.single.data['svg'], '<svg data-d2="a -> b"/>');
    expect(r.data['template'], 'd2');
  });

  test('a .svg file renders as a primitive card (T-494)', () async {
    wire();
    files['logo.svg'] = '<svg id="raw"/>';
    final r = await draw('logo.svg');
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(published.single.data['svg'], '<svg id="raw"/>');
  });

  test('a missing file → notFound, nothing published', () async {
    wire();
    final r = await draw('nope.json');
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.notFound);
    expect(published, isEmpty);
  });

  test('invalid JSON → userError, nothing published', () async {
    wire();
    files['bad.json'] = 'not json';
    final r = await draw('bad.json');
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.userError);
    expect(published, isEmpty);
  });

  test('an unknown template → userError', () async {
    wire();
    files['c.json'] = '{"template":"nope"}';
    final r = await draw('c.json');
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.userError);
  });

  test('missing --file → userError (schema-required)', () async {
    wire();
    final r = await draw(null);
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.userError);
  });

  test('no live UI → toolError, not a hang', () async {
    wire(liveUi: false);
    files['card.json'] = '{"svg":"<svg/>"}';
    final r = await draw('card.json');
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.toolError);
    expect(published, isEmpty);
  });
}
