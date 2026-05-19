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

/// Unwrap an `_argv` IpcRequest into the inner parsed request, or
/// return an error response if the envelope is malformed or the
/// argv doesn't parse. Pure function — no dispatch. Used by both
/// the IPC server (which needs the unwrapped cmd to decide whether
/// to enter streaming mode for `tail --events`, per T-129) and the
/// dispatcher-side handler below.
ArgvParseResult unwrapArgvRequest(IpcRequest outer) {
  final raw = outer.args['argv'];
  if (raw is! List) {
    return ArgvError(IpcResponse.err(
      id: outer.id,
      error: IpcError(
        code: IpcExitCode.userError,
        kind: IpcErrorKind.userError,
        message: '_argv requires args.argv to be a JSON array',
      ),
    ));
  }
  return parseArgv(raw.cast<String>(), requestId: outer.id);
}

/// Wire the `_argv` sentinel handler onto [dispatcher]. The handler
/// unwraps the inner argv via [unwrapArgvRequest], dispatches the
/// resulting request through the same dispatcher, and otherwise
/// returns the pre-built error response. Kept registered for the
/// non-streaming path; the IPC server intercepts before dispatch
/// for `tail --events` (T-129).
void registerArgvUnwrap(DaemonDispatcher dispatcher) {
  dispatcher.register(argvSentinelCmd, (outer) async {
    return switch (unwrapArgvRequest(outer)) {
      ArgvParsed(:final request) => await dispatcher.dispatch(request),
      ArgvError(:final response) => response,
    };
  });
}
