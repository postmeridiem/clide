/// Registers the window-lifecycle verbs — the CLI half of the tray (T-590,
/// D-110; D-6 parity with the tray menu and the window's close button):
///
///   `clide window show`       — show and raise this workspace's window
///   `clide window hide`       — hide it to the tray (refused with no tray host)
///   `clide app quit [--all]`  — quit this window's process, or every clide window
///
/// The native window lives behind a Flutter method channel, so the handler
/// talks to an injected [WindowHost] port and stays Flutter-free (`dart test`).
library;

import 'dart:async';

import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';

/// The native window, as the verbs see it. Each call reports whether the
/// platform carried it out — false on a platform without the native half, and
/// for [hide] when nothing (no tray host, no loader) could bring the window
/// back: a hidden window nobody can reach is worse than a refused hide.
abstract class WindowHost {
  Future<bool> show();
  Future<bool> hide();

  /// Quit this process, or with [all] every clide window. The caller has
  /// already answered its request — the process may be gone when this returns.
  Future<bool> quit({required bool all});
}

/// How long `app.quit` waits after answering before it quits, so the reply
/// reaches the client instead of an EOF.
const Duration kQuitReplyGrace = Duration(milliseconds: 150);

/// Register `window.show`, `window.hide` and `app.quit`. [host] is late-bound
/// (the kernel exists only after boot); null degrades to a clear error.
void registerWindowCommands(DaemonDispatcher d, WindowHost? Function() host, {Duration quitGrace = kQuitReplyGrace}) {
  d.register('window.show', (req) => _run(req, host(), (h) => h.show(), 'shown', 'this platform cannot show the window'));
  d.register('window.hide', (req) => _run(req, host(), (h) => h.hide(), 'hidden', 'no tray to bring the window back from — use `clide app quit` to close it'));
  d.register('app.quit', (req) async {
    final h = host();
    if (h == null) return _err(req.id, 'window host unavailable in this context');
    final all = req.args['all'] == true;
    // Answer first, quit after: the reply must be on the wire before the
    // process (and its socket) goes away.
    unawaited(Future<void>.delayed(quitGrace, () => h.quit(all: all)));
    return IpcResponse.ok(id: req.id, data: {'quitting': all ? 'all' : 'this'});
  }, schema: const CommandSchema(args: {'all': ArgSpec(type: ArgType.boolean)}));
}

Future<IpcResponse> _run(IpcRequest req, WindowHost? host, Future<bool> Function(WindowHost) op, String key, String refusal) async {
  if (host == null) return _err(req.id, 'window host unavailable in this context');
  if (!await op(host)) return _err(req.id, refusal);
  return IpcResponse.ok(id: req.id, data: {key: true});
}

IpcResponse _err(String id, String message) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: message),
);
