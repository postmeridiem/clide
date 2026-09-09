/// Tests for `clipboard.set` / `clipboard.history` — the CLI half of copy
/// (T-584, D-6). Covers what the verb writes, what it announces, and the two
/// deliberate absences: no read verb, and no toast on a user's own copy.
library;

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/clipboard_commands.dart';
import 'package:test/test.dart';

void main() {
  late List<String> written;
  late List<({String publisher, String channel, Map<String, Object?> data})> published;
  late DaemonDispatcher d;

  void wire({bool liveUi = true}) {
    written = [];
    published = [];
    d = DaemonDispatcher();
    registerClipboardCommands(
      d,
      () => liveUi ? (text) async => written.add(text) : null,
      () => liveUi ? (publisher, channel, data) => published.add((publisher: publisher, channel: channel, data: data)) : null,
      history: () => liveUi ? () => written.reversed.toList(growable: false) : null,
    );
  }

  Future<IpcResponse> set(List<String> positional) => d.dispatch(IpcRequest(id: '1', cmd: 'clipboard.set', args: {'positional': positional}));

  test('set writes the text to the clipboard', () async {
    wire();
    final r = await set(['git rebase -i HEAD~3']);

    expect(r.ok, isTrue, reason: r.error?.message);
    expect(written, ['git rebase -i HEAD~3']);
    expect(r.data['set'], isTrue);
    expect(r.data['length'], 20);
  });

  test('set announces itself, because it discards what the user had staged', () async {
    wire();
    await set(['git status']);

    expect(published, hasLength(1));
    expect(published.single.channel, 'toast');
    expect(published.single.data['message'], contains('git status'));
  });

  test('a long entry is elided in the toast rather than dumped into it', () async {
    wire();
    await set(['x' * 400]);

    final message = published.single.data['message']! as String;
    expect(message.length, lessThan(120));
    expect(message, endsWith('…'));
  });

  test('a multi-line entry is flattened for the toast but written verbatim', () async {
    wire();
    await set(['one\n\ntwo']);

    expect(written.single, 'one\n\ntwo', reason: 'the clipboard gets the real text, not the preview');
    expect(published.single.data['message'], contains('one two'));
  });

  test('an empty string clears the buffer — a missing one is an error', () async {
    wire();
    final cleared = await set(['']);
    expect(cleared.ok, isTrue, reason: 'clearing is a legitimate request');
    expect(written, ['']);

    final missing = await d.dispatch(IpcRequest(id: '2', cmd: 'clipboard.set', args: const {}));
    expect(missing.ok, isFalse, reason: 'a malformed call must not silently wipe the clipboard');
    expect(written, hasLength(1), reason: 'nothing further was written');
  });

  test('history reports what the service wrote, newest first', () async {
    wire();
    await set(['first']);
    await set(['second']);

    final r = await d.dispatch(IpcRequest(id: '3', cmd: 'clipboard.history', args: const {}));
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(r.data['entries'], ['second', 'first']);
  });

  test('there is no read verb — the clipboard holds the user secrets', () async {
    wire();
    final r = await d.dispatch(IpcRequest(id: '4', cmd: 'clipboard.get', args: const {}));
    expect(r.ok, isFalse, reason: 'clipboard.get must not exist; reading is not the symmetric peer of writing');
  });

  test('without a live UI it fails honestly instead of pretending', () async {
    wire(liveUi: false);

    final s = await set(['anything']);
    expect(s.ok, isFalse);
    expect(s.error!.message, contains('no live UI'));

    final h = await d.dispatch(IpcRequest(id: '5', cmd: 'clipboard.history', args: const {}));
    expect(h.ok, isFalse);
  });

  test('a set still succeeds when there is no bus to toast on', () async {
    // The write is the contract; the toast is the courtesy. Losing the
    // courtesy must not report a clipboard that was actually set as failed.
    written = [];
    published = [];
    d = DaemonDispatcher();
    registerClipboardCommands(
      d,
      () =>
          (text) async => written.add(text),
      () => null,
      history: () =>
          () => written,
    );

    final r = await set(['still works']);
    expect(r.ok, isTrue, reason: r.error?.message);
    expect(written, ['still works']);
    expect(published, isEmpty);
  });
}
