/// Tests for `ui.open` — the drive-half of D-6 parity (T-231). Verifies it
/// publishes the right MessageBus 'selection' per reader, validates input,
/// and fails honestly when there is no live UI.
library;

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/ui_command.dart';
import 'package:test/test.dart';

void main() {
  // Records what would be published to the kernel MessageBus.
  late List<({String publisher, String channel, Map<String, Object?> data})> published;
  late DaemonDispatcher d;

  void wire({bool liveUi = true}) {
    published = [];
    d = DaemonDispatcher();
    registerUiCommands(d, () {
      if (!liveUi) return null;
      return (publisher, channel, data) => published.add((publisher: publisher, channel: channel, data: data));
    });
  }

  Future<IpcResponse> open(List<String> positional) => d.dispatch(
        IpcRequest(id: '1', cmd: 'ui.open', args: {'positional': positional}),
      );

  test('ui open tickets T-48 publishes a tickets selection', () async {
    wire();
    final r = await open(['tickets', 'T-48']);
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(r.data['opened'], isTrue);
    expect(published, hasLength(1));
    expect(published.single.publisher, 'builtin.tickets');
    expect(published.single.channel, 'selection');
    expect(published.single.data, {'id': 'T-48'});
  });

  test('decisions keys on id; markdown keys on path', () async {
    wire();
    await open(['decisions', 'D-17']);
    await open(['markdown', 'docs/initial-plan.md']);
    expect(published[0].publisher, 'builtin.decisions');
    expect(published[0].data, {'id': 'D-17'});
    expect(published[1].publisher, 'builtin.markdown');
    expect(published[1].data, {'path': 'docs/initial-plan.md'});
  });

  test('named args work too (reader/ref)', () async {
    wire();
    final r = await d.dispatch(IpcRequest(id: '1', cmd: 'ui.open', args: {'reader': 'tickets', 'ref': 'T-7'}));
    expect(r.ok, isTrue);
    expect(published.single.data, {'id': 'T-7'});
  });

  test('unknown reader → userError, nothing published', () async {
    wire();
    final r = await open(['canvas', 'foo']);
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.userError);
    expect(published, isEmpty);
  });

  test('missing ref → userError', () async {
    wire();
    final r = await open(['tickets']);
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.userError);
    expect(published, isEmpty);
  });

  test('no live UI (null publisher) → toolError, not a hang', () async {
    wire(liveUi: false);
    final r = await open(['tickets', 'T-48']);
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.toolError);
  });
}
