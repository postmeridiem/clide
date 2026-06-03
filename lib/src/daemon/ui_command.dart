/// Registers `ui.open` — the drive-half of D-6 parity (T-231).
///
/// Epic C (T-218) gave the CLI the *observe* half: `clide status` / `pane
/// list` read live UI state. This is the complement — the agent asks the
/// GUI to open a doc in one of its readers, so it can say "look at this
/// with me." Opening a reader doc is otherwise a UI-only action (a click
/// publishes a `selection` to the kernel MessageBus); this verb publishes
/// the same message from the CLI.
///
///   clide ui open tickets   T-48
///   clide ui open decisions D-17
///   clide ui open markdown  docs/initial-plan.md
///
/// The handler is decoupled from the kernel: it takes a [MessagePublisher]
/// callback (wired to the MessageBus in main.dart), so this file stays
/// Flutter-free and runs under `dart test`.
library;

import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';

/// Publishes a message to the kernel MessageBus. `void Function(publisher,
/// channel, data)` — the tear-off of `MessageBus.publish`.
typedef MessagePublisher = void Function(String publisher, String channel, Map<String, Object?> data);

/// The readers `ui.open` can target → (bus publisher id, payload key the
/// reader reads its entry from). Matches each reader's `ReaderNav` dataKey
/// (tickets/decisions key on `id`; markdown on `path`).
const Map<String, ({String publisher, String dataKey})> _readers = {
  'tickets': (publisher: 'builtin.tickets', dataKey: 'id'),
  'decisions': (publisher: 'builtin.decisions', dataKey: 'id'),
  'markdown': (publisher: 'builtin.markdown', dataKey: 'path'),
};

void registerUiCommands(DaemonDispatcher d, MessagePublisher? Function() publisher) {
  d.register('ui.open', (req) async => _open(req, publisher));
}

IpcResponse _userErr(String id, String message, {String? hint}) => IpcResponse.err(
      id: id,
      error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message, hint: hint),
    );

Future<IpcResponse> _open(IpcRequest req, MessagePublisher? Function() publisherSource) async {
  // Accept CLI positionals (`ui open <reader> <ref>`) or named args.
  final positional = (req.args['positional'] as List?)?.whereType<String>().toList() ?? const <String>[];
  final reader = (req.args['reader'] as String?) ?? (positional.isNotEmpty ? positional[0] : null);
  final ref = (req.args['ref'] as String?) ?? (positional.length > 1 ? positional[1] : null);

  if (reader == null) {
    return _userErr(req.id, 'reader is required', hint: 'one of: ${_readers.keys.join(', ')}');
  }
  final target = _readers[reader];
  if (target == null) {
    return _userErr(req.id, 'unknown reader: $reader', hint: 'one of: ${_readers.keys.join(', ')}');
  }
  if (ref == null || ref.isEmpty) {
    return _userErr(req.id, 'a doc id/path is required (e.g. `ui open $reader <ref>`)');
  }

  final publish = publisherSource();
  if (publish == null) {
    // No live UI bus — headless / CLI-only context. Honest failure, not a hang.
    return IpcResponse.err(
      id: req.id,
      error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'no live UI to drive (clide is not running a GUI)'),
    );
  }
  publish(target.publisher, 'selection', {target.dataKey: ref});
  return IpcResponse.ok(id: req.id, data: {'reader': reader, 'ref': ref, 'opened': true});
}
