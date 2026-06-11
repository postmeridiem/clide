/// Translate the argv tail of a `clide …` shell invocation into an
/// [IpcRequest] the server can dispatch. Pure Dart, no I/O.
///
/// Second slice of T-99 (D-56 path a). The C client (T-126) is a
/// dumb pipe: it sends `{argv:[…]}` over the socket, the server
/// runs this function, then dispatches. Keeping the CLI grammar in
/// Dart means the translator can be unit-tested and shared with
/// `make t T=…` workflows that don't shell out to the C client.
///
/// Grammar (per D-6):
///
/// ```
/// clide SUBSYSTEM VERB [positional...] [--flag value] [-- passthrough...]
/// clide UMBRELLA              # status, tail, version, ping
/// ```
///
/// The umbrella entries have no subsystem.verb split; the first arg
/// IS the command id. D-6 lists `tail` and `status` explicitly; the
/// dispatcher also recognises `ping` and `version` (registered by
/// default in [DaemonDispatcher]).
library;

import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/schema_v1.dart';

/// Umbrella commands — single-token names with no subsystem.verb
/// split. Match the IDs the dispatcher exposes directly. `tail` and
/// `events` are handled by the IPC server itself (streaming / cursor-pull
/// event reads, T-129 / T-223) rather than the dispatcher.
const Set<String> _umbrellaCommands = {'status', 'tail', 'events', 'version', 'ping', 'capabilities'};

/// Sealed result of translating argv. Caller (the IPC server, or the
/// C client wrapper in T-126) handles either branch.
sealed class ArgvParseResult {
  const ArgvParseResult();
}

/// Successful parse — the [request] is ready to dispatch.
class ArgvParsed extends ArgvParseResult {
  const ArgvParsed(this.request);
  final IpcRequest request;
}

/// argv was malformed at the syntactic layer (no subsystem, broken
/// flag, etc.). The [response] is ready to write back to the client
/// — exit code in `response.error.code` follows pql's sysexit
/// convention (64 = EX_USAGE for shape errors).
class ArgvError extends ArgvParseResult {
  const ArgvError(this.response);
  final IpcResponse response;
}

/// Translate [argv] (everything after the program name) into an
/// [IpcRequest] or an [ArgvError]. [requestId] is the wire id the
/// server should echo on the response — caller assigns it (typically
/// a counter or random short string).
ArgvParseResult parseArgv(List<String> argv, {required String requestId}) {
  if (argv.isEmpty) {
    return ArgvError(_err(requestId, 'usage: clide <subsystem> <verb> [args...]'));
  }

  final first = argv[0];
  // A clide:// deep link (T-56): the OS scheme handler invokes
  // `clide clide://open?path=…&line=…`, which lands here as the first arg and
  // routes through the same IPC path to the running app (no second instance).
  if (first.startsWith('clide://')) {
    return _deepLinkToRequest(first, requestId);
  }
  // Umbrella commands: single-token name, no verb required.
  if (_umbrellaCommands.contains(first)) {
    final tail = argv.sublist(1);
    final parsed = _parseTail(tail);
    if (parsed is _TailError) {
      return ArgvError(_err(requestId, parsed.message));
    }
    return ArgvParsed(IpcRequest(id: requestId, cmd: first, args: (parsed as _TailOk).toArgs()));
  }

  // Subsystem.verb form: need at least two tokens.
  if (argv.length < 2) {
    return ArgvError(_err(requestId, 'usage: clide $first <verb> [args...]'));
  }
  final subsystem = first;
  final verb = argv[1];
  if (!_isValidIdentifier(subsystem)) {
    return ArgvError(_err(requestId, 'invalid subsystem: $subsystem'));
  }
  if (!_isValidIdentifier(verb)) {
    return ArgvError(_err(requestId, 'invalid verb: $verb'));
  }
  final tail = argv.sublist(2);
  final parsed = _parseTail(tail);
  if (parsed is _TailError) {
    return ArgvError(_err(requestId, parsed.message));
  }
  return ArgvParsed(IpcRequest(id: requestId, cmd: '$subsystem.$verb', args: (parsed as _TailOk).toArgs()));
}

/// Route a `clide://` deep link to the `deeplink.invoke` command (T-56). A
/// clide:// URL is an UNTRUSTED external vector — any webpage can fire one — so
/// it is NOT translated into a command here. The raw URL is handed to the
/// deeplink handler, which validates it against a paranoid (default-deny)
/// allowlist and prompts the user before doing anything (D-90).
ArgvParseResult _deepLinkToRequest(String url, String requestId) => ArgvParsed(
  IpcRequest(
    id: requestId,
    cmd: 'deeplink.invoke',
    args: {
      'positional': [url],
    },
  ),
);

// -- internals --------------------------------------------------------------

sealed class _TailParseResult {
  const _TailParseResult();
}

class _TailOk extends _TailParseResult {
  const _TailOk({required this.positional, required this.flags, required this.passthrough});
  final List<String> positional;
  final Map<String, Object?> flags;
  final List<String> passthrough;

  Map<String, Object?> toArgs() => {
    if (positional.isNotEmpty) 'positional': positional,
    if (flags.isNotEmpty) 'flags': flags,
    if (passthrough.isNotEmpty) 'passthrough': passthrough,
  };
}

class _TailError extends _TailParseResult {
  const _TailError(this.message);
  final String message;
}

/// Walk [tail] splitting it into positionals, flags, and (everything
/// after a lone `--`) passthrough.
///
/// Flag forms:
///   --key=value     → flags[key] = value
///   --key value     → flags[key] = value (value can't start with `--`)
///   --key           → flags[key] = true  (boolean; next token is `--…` or end)
///
/// Anything not matching `--` is a positional. A bare `--` token
/// terminates option parsing — everything after lands in passthrough.
_TailParseResult _parseTail(List<String> tail) {
  final positional = <String>[];
  final flags = <String, Object?>{};
  final passthrough = <String>[];
  var i = 0;
  var inPassthrough = false;
  while (i < tail.length) {
    final t = tail[i];
    if (inPassthrough) {
      passthrough.add(t);
      i++;
      continue;
    }
    if (t == '--') {
      inPassthrough = true;
      i++;
      continue;
    }
    if (t.startsWith('--')) {
      final body = t.substring(2);
      if (body.isEmpty) {
        return const _TailError('empty flag: "--" with no name; use a bare "--" to terminate options');
      }
      final eq = body.indexOf('=');
      if (eq >= 0) {
        final key = body.substring(0, eq);
        final value = body.substring(eq + 1);
        if (!_isValidFlagName(key)) {
          return _TailError('invalid flag name: $key');
        }
        flags[key] = value;
        i++;
        continue;
      }
      // --key with no `=` — peek at next token.
      if (!_isValidFlagName(body)) {
        return _TailError('invalid flag name: $body');
      }
      final next = i + 1 < tail.length ? tail[i + 1] : null;
      if (next == null || next == '--' || next.startsWith('--')) {
        // Boolean flag — no value follows.
        flags[body] = true;
        i++;
      } else {
        flags[body] = next;
        i += 2;
      }
      continue;
    }
    positional.add(t);
    i++;
  }
  return _TailOk(positional: positional, flags: flags, passthrough: passthrough);
}

/// Subsystems + verbs use the same shape — letters, digits, dot,
/// hyphen, underscore. Reject anything else so a typo doesn't reach
/// the dispatcher as a wire-shaped command id.
bool _isValidIdentifier(String s) {
  if (s.isEmpty) return false;
  for (final code in s.codeUnits) {
    final isLetter = (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a);
    final isDigit = code >= 0x30 && code <= 0x39;
    final isOther = code == 0x2e /* . */ || code == 0x2d /* - */ || code == 0x5f /* _ */;
    if (!isLetter && !isDigit && !isOther) return false;
  }
  return true;
}

/// Flag names are the same alphabet plus `.` is rare but allowed.
/// Tighter than identifier here would just create false rejections.
bool _isValidFlagName(String s) => _isValidIdentifier(s);

IpcResponse _err(String id, String message) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message),
);
