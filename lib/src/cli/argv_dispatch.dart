/// Register the `_argv` sentinel command on a [DaemonDispatcher].
///
/// The C client (T-126) doesn't know the dispatcher's command surface
/// — it ships raw argv across the wire under cmd `_argv`. This handler
/// runs [parseArgv] on the embedded argv and either dispatches the
/// resulting [IpcRequest] or returns the pre-built error response.
///
/// Why a sentinel cmd rather than a top-level parse step in the IPC
/// server: keeps the server transport-agnostic — every consumer that
/// already has a typed [IpcRequest] goes the direct path; only the
/// CLI's raw-argv envelope hits this unwrap shim.
library;

import 'package:clide/src/cli/argv_to_request.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/schema_v1.dart';

/// Sentinel command id the C `clide` client sends. Anything else
/// goes through the normal dispatcher path unchanged.
const String argvSentinelCmd = '_argv';

/// Wire the `_argv` sentinel handler onto [dispatcher]. The handler:
///   1. Extracts `args.argv` as a List&lt;String&gt;.
///   2. Calls [parseArgv].
///   3. If parsed → re-dispatches the inner request through the
///      *same* dispatcher (so per-handler logic runs once).
///   4. If error → returns the pre-built [IpcResponse] verbatim,
///      patched with the outer request id so the client correlates.
void registerArgvUnwrap(DaemonDispatcher dispatcher) {
  dispatcher.register(argvSentinelCmd, (outer) async {
    final raw = outer.args['argv'];
    if (raw is! List) {
      return IpcResponse.err(
        id: outer.id,
        error: IpcError(
          code: IpcExitCode.userError,
          kind: IpcErrorKind.userError,
          message: '_argv requires args.argv to be a JSON array',
        ),
      );
    }
    final argv = raw.cast<String>();
    final result = parseArgv(argv, requestId: outer.id);
    return switch (result) {
      ArgvParsed(:final request) => dispatcher.dispatch(request),
      ArgvError(:final response) => response,
    };
  });
}
