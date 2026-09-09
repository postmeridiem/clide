/// Registers the `clipboard.*` verbs — the CLI half of copy/paste (D-6, T-584).
///
/// Copying was a UI-only action: the kernel `ClideClipboard` has held
/// `writePlain` + a history ring since the terminal gained copy/paste, and
/// D-109 gave every surface a right-click Copy, but nothing exposed either to
/// the CLI. So an agent could tell you to run a command and not hand it to you.
///
///   clide clipboard set "git rebase -i HEAD~3"
///   clide clipboard history
///
/// **There is deliberately no read verb.** A clipboard routinely holds
/// passwords, tokens and private text the user copied for their own purposes;
/// an agent that can read it on demand can read all of that. Writing is a
/// service, reading is surveillance, and the two are not symmetric just because
/// they share a buffer. `history` reports only what came through this service.
///
/// Setting the clipboard is destructive — it discards whatever the user had
/// staged to paste — so a write also raises a toast. That is not decoration: it
/// is the only signal that their paste buffer changed under them.
///
/// **The toast belongs to this verb, not to copying.** A right-click Copy runs
/// through Flutter's `copySelection` and never reaches here, which is correct:
/// the user performed that action and does not need to be told it happened.
/// Only a write they did not make is worth announcing.
///
/// Kept free of Flutter imports (the kernel clipboard is not) by taking
/// callbacks, so this file runs under `dart test` like its `ui.*` peers.
library;

import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';
import 'ui_command.dart' show MessagePublisher;

/// Writes plain text to the clipboard — the tear-off of
/// `ClideClipboard.writePlain`.
typedef ClipboardWriter = Future<void> Function(String text);

/// Reads back what this service has written, newest first — the tear-off of
/// `ClideClipboard.historyOf<String>()`.
typedef ClipboardHistorySource = List<String> Function();

/// Longest entry echoed back in a toast before it is elided; the toast is a
/// confirmation, not a display surface.
const int _toastPreviewChars = 60;

void registerClipboardCommands(
  DaemonDispatcher d,
  ClipboardWriter? Function() writer,
  MessagePublisher? Function() publisher, {
  ClipboardHistorySource? Function()? history,
}) {
  d.register(
    'clipboard.set',
    (req) async => _set(req, writer, publisher),
    schema: const CommandSchema(positional: ['text'], args: {'text': ArgSpec(required: true)}),
  );
  d.register('clipboard.history', (req) async => _history(req, history));
}

IpcResponse _userErr(String id, String message, {String? hint}) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message, hint: hint),
);

IpcResponse _noUi(String id) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'no live UI to drive (clide is not running a GUI)'),
);

/// `clide clipboard set <text>` — put text on the user's paste buffer.
Future<IpcResponse> _set(IpcRequest req, ClipboardWriter? Function() writerSource, MessagePublisher? Function() publisherSource) async {
  final text = req.args['text'] as String?;
  // An empty string is a legitimate request (clear the buffer); a missing one
  // is not, since silently clearing on a malformed call would lose data.
  if (text == null) {
    return _userErr(req.id, 'text is required', hint: 'e.g. `clide clipboard set "git status"`');
  }

  final write = writerSource();
  if (write == null) return _noUi(req.id);
  await write(text);

  // Best-effort: the write is the contract, the toast is the courtesy. A
  // missing bus must not fail a clipboard that was actually set.
  publisherSource()?.call('cli', 'toast', {'message': 'Copied to clipboard: ${_preview(text)}', 'severity': 'info'});

  return IpcResponse.ok(id: req.id, data: {'set': true, 'length': text.length});
}

/// `clide clipboard history` — what this service has written, newest first.
Future<IpcResponse> _history(IpcRequest req, ClipboardHistorySource? Function()? historySource) async {
  final read = historySource?.call();
  if (read == null) return _noUi(req.id);
  return IpcResponse.ok(id: req.id, data: {'entries': read()});
}

/// One-line, length-capped rendering for the toast.
String _preview(String text) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return '(empty)';
  if (flat.length <= _toastPreviewChars) return flat;
  return '${flat.substring(0, _toastPreviewChars)}…';
}
