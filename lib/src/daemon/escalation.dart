/// Confirming escalating commands from agents (D-115).
///
/// An escalate-tier command that reaches clide over the socket from an agent
/// waits for the user: the dispatcher hands an [EscalationRequest] to the
/// app's [EscalationGate] (an in-app modal) and runs the command only on an
/// allow. The Claude allow rules can't be the boundary on their own — the
/// socket accepts any process the user owns (D-71), with or without the
/// `clide` binary — so the check lives here, where every request lands.
///
/// **Who is an agent.** The IPC server records the connecting process's pid
/// ([CallerInfo.pid]); an [AgentDetector] walks its ancestry for a `claude`
/// process. That covers sessions clide hosts and a `claude` the user started
/// in a terminal alike (the user chose both). The user's own shell doesn't
/// descend from one, so their typing runs as before. Where the ancestry
/// can't be read, the caller is treated as an agent: confirming too often
/// beats running code unasked.
///
/// In-app UI actions never pass through the socket, so they carry no
/// [CallerInfo] and never confirm.
///
/// Flutter-free: the daemon side runs under plain `dart test`.
library;

import 'dart:async';
import 'dart:io';

/// The Zone key the IPC server stores a request's [CallerInfo] under. A
/// Zone rather than a parameter so a nested dispatch — the `_argv` unwrap
/// re-dispatching its inner command — inherits the caller automatically.
const Symbol callerZoneKey = #clideCaller;

/// The caller of the request being dispatched, or null for an in-app call.
CallerInfo? currentCaller() => Zone.current[callerZoneKey] as CallerInfo?;

/// Who sent a socket request: the peer's pid, classified lazily — only an
/// escalating command ever needs to know whether an agent sent it.
class CallerInfo {
  CallerInfo({required this.pid, required AgentDetector detector}) : _detector = detector;

  /// The connecting process, or null when the platform couldn't say.
  final int? pid;
  final AgentDetector _detector;
  Future<AgentIdentity?>? _agent;

  /// The agent this call descends from, or null when a person sent it.
  Future<AgentIdentity?> agent() => _agent ??= _detector.agentOf(pid);
}

/// An agent process a request descends from. [key] scopes "allow for this
/// session": the same agent process, the same exact command.
class AgentIdentity {
  const AgentIdentity({required this.key, required this.label});

  /// Stable for the agent process's life, e.g. `claude:4242`.
  final String key;

  /// What the confirm shows, e.g. `claude (pid 4242)`.
  final String label;
}

/// Decides whether a pid descends from an agent.
abstract class AgentDetector {
  Future<AgentIdentity?> agentOf(int? pid);
}

/// One process in an ancestry walk. [start] identifies this incarnation of
/// the pid (Linux: start time in clock ticks), so a session approval can't
/// pass to an unrelated process that later reuses the pid; null if unknown.
typedef ProcessEntry = ({int ppid, String name, List<String> argv, String? start});

/// Reads one process's parent, name and argv; null if it can't be read.
typedef ProcessReader = Future<ProcessEntry?> Function(int pid);

/// Walks the ancestry of the caller looking for a `claude` process — by
/// executable name, or by an argv that runs Claude Code under node. When
/// the pid is unknown or the walk can't start, the caller counts as an
/// agent ([unknownAgent]).
///
/// The walk stops at [stopAt] — clide itself. A clide launched from an
/// agent (`make run` in a Claude session) has `claude` above it, and without
/// the stop every pane shell the user types in would inherit that ancestry.
/// A hosted session is clide's child, so it is found before the stop.
class ProcessTreeAgentDetector implements AgentDetector {
  ProcessTreeAgentDetector({ProcessReader? reader, int? stopAt}) : _read = reader ?? defaultProcessReader, _stopAt = stopAt ?? pid;

  final ProcessReader _read;
  final int _stopAt;

  /// Used when the caller can't be classified: confirm rather than trust.
  static const AgentIdentity unknownAgent = AgentIdentity(key: 'unknown', label: 'an unidentified process');

  static const int _maxDepth = 64;

  @override
  Future<AgentIdentity?> agentOf(int? pid) async {
    if (pid == null || pid <= 0) return unknownAgent;
    var current = pid;
    for (var depth = 0; depth < _maxDepth && current > 1 && current != _stopAt; depth++) {
      final entry = await _read(current);
      if (entry == null) return depth == 0 ? unknownAgent : null;
      if (isClaudeProcess(entry.name, entry.argv)) {
        final incarnation = entry.start == null ? '' : '@${entry.start}';
        return AgentIdentity(key: 'claude:$current$incarnation', label: 'claude (pid $current)');
      }
      if (entry.ppid == current) break;
      current = entry.ppid;
    }
    return null;
  }

  /// Whether a process is Claude Code: the `claude` executable, or node
  /// running the `@anthropic-ai/claude-code` package.
  static bool isClaudeProcess(String name, List<String> argv) {
    if (name == 'claude') return true;
    if (argv.isNotEmpty && argv.first.split('/').last == 'claude') return true;
    return argv.any((a) => a.contains('@anthropic-ai/claude-code'));
  }
}

/// The platform reader: `/proc` on Linux, `ps` on macOS, nothing elsewhere
/// (every caller then counts as an agent).
Future<ProcessEntry?> defaultProcessReader(int pid) async {
  if (Platform.isLinux) return readProcEntry(pid, procRoot: '/proc');
  if (Platform.isMacOS) return _readPsEntry(pid);
  return null;
}

/// Read [pid] from a Linux-style proc filesystem at [procRoot].
Future<ProcessEntry?> readProcEntry(int pid, {required String procRoot}) async {
  try {
    final stat = await File('$procRoot/$pid/stat').readAsString();
    // `pid (comm) state ppid ...` — comm may contain spaces and parens, so
    // split on the LAST ')'.
    final close = stat.lastIndexOf(')');
    final open = stat.indexOf('(');
    if (open < 0 || close < open) return null;
    final name = stat.substring(open + 1, close);
    // Fields after comm, 0-based: state(0) ppid(1) ... starttime(19).
    final rest = stat.substring(close + 2).split(' ');
    final ppid = int.tryParse(rest.length > 1 ? rest[1] : '');
    if (ppid == null) return null;
    final start = rest.length > 19 ? rest[19] : null;
    final raw = await File('$procRoot/$pid/cmdline').readAsString();
    final argv = raw.split('\u0000').where((a) => a.isNotEmpty).toList();
    return (ppid: ppid, name: name, argv: argv, start: start);
  } on FileSystemException {
    return null;
  }
}

Future<ProcessEntry?> _readPsEntry(int pid) async {
  try {
    final r = await Process.run('ps', ['-o', 'ppid=,comm=', '-p', '$pid']);
    if (r.exitCode != 0) return null;
    final line = (r.stdout as String).trim();
    final space = line.indexOf(' ');
    if (space < 0) return null;
    final ppid = int.tryParse(line.substring(0, space).trim());
    if (ppid == null) return null;
    final comm = line.substring(space + 1).trim();
    return (ppid: ppid, name: comm.split('/').last, argv: [comm], start: null);
  } on ProcessException {
    return null;
  }
}

/// The user's answer to an escalation confirm.
enum EscalationVerdict {
  /// Refuse (also what dismissing the modal means).
  deny,

  /// Run this one call.
  once,

  /// Run it, and this exact command from the same agent until it exits.
  session,
}

/// What the confirm shows: which agent wants to run which exact command.
class EscalationRequest {
  const EscalationRequest({required this.command, required this.args, required this.agent, this.reason});

  /// The dispatcher command id, e.g. `pane.spawn`.
  final String command;

  /// The validated arguments it would run with.
  final Map<String, Object?> args;

  /// The agent asking.
  final AgentIdentity agent;

  /// Why this call needs a confirm when the command alone doesn't say,
  /// e.g. `writes a protected file`.
  final String? reason;
}

/// Asks the user about one [EscalationRequest].
typedef EscalationGate = Future<EscalationVerdict> Function(EscalationRequest request);
