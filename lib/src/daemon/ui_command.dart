/// Registers the `ui.*` drive/observe verbs — the parity peers of D-6
/// (`ui.open` T-231, `ui.toast` T-50, `ui.filter` T-270).
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

import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';

/// Publishes a message to the kernel MessageBus. `void Function(publisher,
/// channel, data)` — the tear-off of `MessageBus.publish`.
typedef MessagePublisher = void Function(String publisher, String channel, Map<String, Object?> data);

/// The readers `ui.open` can target → (bus publisher id, payload key the
/// reader reads its entry from). Matches each reader's `ReaderNav` dataKey
/// (tickets/decisions key on `id`; markdown on `path`). `diff` and `canvas`
/// are not ReaderNav readers — they key on `path` and their extensions
/// subscribe to the same `selection` channel to reveal their tab + focus
/// the file (T-233, T-322).
const Map<String, ({String publisher, String dataKey})> _readers = {
  'tickets': (publisher: 'builtin.tickets', dataKey: 'id'),
  'decisions': (publisher: 'builtin.decisions', dataKey: 'id'),
  'markdown': (publisher: 'builtin.markdown', dataKey: 'path'),
  'diff': (publisher: 'builtin.diff', dataKey: 'path'),
  'canvas': (publisher: 'builtin.canvas', dataKey: 'path'),
};

/// Severities the toast verb accepts — mirrors `ToastSeverity` (kept as a
/// literal so this file stays Flutter-free for `dart test`).
const Set<String> _toastSeverities = {'success', 'warning', 'error', 'info'};

/// Reads the current filter value for an addressable box from the kernel's
/// `FilterStateCache` — the observe-half of `ui.filter`. Returns null when
/// nothing has reported a value for that address (or there is no live UI).
typedef FilterValueSource = String? Function(String address);

void registerUiCommands(DaemonDispatcher d, MessagePublisher? Function() publisher, {FilterValueSource? filterValue}) {
  d.register('ui.open', (req) async => _open(req, publisher));
  d.register('ui.toast', (req) async => _toast(req, publisher));
  d.register(
    'ui.filter',
    (req) async => _filter(req, publisher, filterValue),
    schema: const CommandSchema(positional: ['address', 'query'], args: {'address': ArgSpec(required: true), 'query': ArgSpec()}),
  );
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

/// `clide ui toast "message" [--severity success|warning|error|info]
/// [--duration MS]` — raise a toast in the live GUI from the CLI. The
/// drive-half complement for operation feedback (T-50): an agent (or script)
/// can surface "done / failed" to the user's screen. Publishes a message on
/// the `toast` channel that the kernel ToastService consumes — the same path
/// a UI emitter uses, so no GUI coupling here.
Future<IpcResponse> _toast(IpcRequest req, MessagePublisher? Function() publisherSource) async {
  final positional = (req.args['positional'] as List?)?.whereType<String>().toList() ?? const <String>[];
  final flags = req.args['flags'] as Map?;
  // Message: a named arg, else all positionals joined (so an unquoted
  // multi-word message still works).
  final message = (req.args['message'] as String?) ?? (positional.isNotEmpty ? positional.join(' ') : null);
  if (message == null || message.trim().isEmpty) {
    return _userErr(req.id, 'a message is required (e.g. `ui toast "Build finished"`)');
  }
  final severity = (flags?['severity'] as String?) ?? 'info';
  if (!_toastSeverities.contains(severity)) {
    return _userErr(req.id, 'unknown severity: $severity', hint: 'one of: ${_toastSeverities.join(', ')}');
  }
  int? durationMs;
  final durRaw = flags?['duration'];
  if (durRaw != null) {
    durationMs = int.tryParse('$durRaw');
    if (durationMs == null) {
      return _userErr(req.id, 'duration must be an integer number of milliseconds');
    }
  }

  final publish = publisherSource();
  if (publish == null) {
    return IpcResponse.err(
      id: req.id,
      error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'no live UI to drive (clide is not running a GUI)'),
    );
  }
  // Channel literal must match ToastService's `toastChannel`.
  publish('cli', 'toast', {'message': message, 'severity': severity, 'durationMs': ?durationMs});
  return IpcResponse.ok(id: req.id, data: {'message': message, 'severity': severity, 'shown': true});
}

/// `clide ui filter <address> [<text>]` — the drive+observe parity peer for
/// the sidebar filter boxes (T-270, D-6). Routed through the MessageBus so a
/// box reacts identically whether the trigger was a UI keystroke or this
/// verb, keeping extensions first-class (no dispatcher→widget wiring).
///
///   clide ui filter decisions.panel git   # set the filter to "git"
///   clide ui filter decisions.panel ""    # clear it
///   clide ui filter decisions.panel       # read the current value
///
/// `address` is a pane/box id from `clide pane list`. With a `query` arg the
/// verb *drives* — publishes a `filter.set` the box consumes. Without one it
/// *observes* — reads the box's last reported value from the FilterStateCache.
Future<IpcResponse> _filter(IpcRequest req, MessagePublisher? Function() publisherSource, FilterValueSource? filterValue) async {
  final address = req.args['address'] as String?;
  if (address == null || address.isEmpty) {
    return _userErr(req.id, 'an address is required', hint: 'a pane/box id from `clide pane list` (e.g. decisions.panel)');
  }

  // Absent query → observe; present (even empty string) → drive. The schema
  // drops unmapped positionals, so a missing query leaves no `query` key.
  if (!req.args.containsKey('query')) {
    final getter = filterValue;
    if (getter == null) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'no live UI to observe (clide is not running a GUI)'),
      );
    }
    return IpcResponse.ok(id: req.id, data: {'address': address, 'query': getter(address)});
  }

  final query = (req.args['query'] as String?) ?? '';
  final publish = publisherSource();
  if (publish == null) {
    return IpcResponse.err(
      id: req.id,
      error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'no live UI to drive (clide is not running a GUI)'),
    );
  }
  publish(address, 'filter.set', {'query': query});
  return IpcResponse.ok(id: req.id, data: {'address': address, 'query': query, 'set': true});
}
