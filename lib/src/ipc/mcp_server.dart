/// MCP server for `/ide`-compatible Claude Code integrations
/// (T-99 / T-130, per D-68 + D-73).
///
/// **Transport:** HTTP + Server-Sent Events (D-73). The server binds
/// an HTTP listener on a random localhost port at startup and writes
/// a discovery file at `$HOME/.claude/ide/<pid>.lock` so Claude
/// Code's `/ide` command can find us.
///
/// **Protocol:** JSON-RPC 2.0 carried over SSE.
///   - `GET /sse` opens a long-lived stream. The server pushes
///     JSON-RPC responses + notifications as `data: <json>\n\n`
///     events.
///   - `POST /messages?sessionId=<id>` accepts a JSON-RPC request
///     and returns 202; the response lands on the matching session's
///     SSE stream.
///
/// **Surface:** the two minimum tools per D-68 — `mcp__ide__getDiagnostics`
/// and `mcp__ide__executeCode`. Both stubbed today; real
/// implementations land as follow-up tickets once the analyzer
/// integration is ready and we have a clide-side eval surface.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clide/kernel/src/log.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/ipc/envelope.dart';

/// Prefix for clide's own MCP tools — the full command surface, generated
/// from the dispatcher registry (D-86). The `mcp__ide__*` pair is the
/// separate `/ide` minimum (D-68).
const String _clideToolPrefix = 'mcp__clide__';

/// Auth header Claude Code's `/ide` client sends, populated from the lock
/// file's `authToken`. Every request must carry it (T-362): the unix socket
/// is gated by 0600 per D-71, and an unauthenticated localhost HTTP port
/// would bypass that gate wholesale.
const String kMcpAuthHeader = 'x-claude-code-ide-authorization';

/// One connected SSE client. Each session has its own response
/// stream; POST /messages routes back to the right one via the
/// `sessionId` query param.
class _McpSession {
  _McpSession(this.id, this.response);
  final String id;
  final HttpResponse response;
  bool closed = false;

  void send(Map<String, Object?> payload) {
    if (closed) return;
    try {
      response.write('data: ${jsonEncode(payload)}\n\n');
    } catch (_) {
      closed = true;
    }
  }

  Future<void> close() async {
    if (closed) return;
    closed = true;
    try {
      await response.close();
    } catch (_) {}
  }
}

/// HTTP + SSE MCP server. Lifecycle mirrors [IpcServer]: `start()`
/// binds + writes the discovery file; `stop()` unbinds + removes it.
class McpServer {
  McpServer({
    required this.workspaceRoot,
    required this.log,
    this.dispatcher,
    this.discoveryDirOverride,
    this.boundConfigDir,
    this.bindHost = '127.0.0.1',
    this.bindPort = 0,
  });

  /// Workspace root reported in the discovery file. Helps Claude
  /// Code show "which clide is this" when multiple are running.
  final String workspaceRoot;
  final Logger log;

  /// The command dispatcher whose registry drives the `mcp__clide__*` tool
  /// surface and handles `tools/call` (D-86). Null → only the `/ide` minimum
  /// tools are served (tests that don't need the full surface).
  final DaemonDispatcher? dispatcher;

  /// Override of `$HOME/.claude/ide/` for tests. Production code
  /// passes null; tests inject a tempdir.
  final String? discoveryDirOverride;

  /// Returns the Claude config dir bound to this workspace (T-479/T-480), or
  /// null when unbound. When non-null, a copy of the discovery lock is also
  /// written into that dir's `ide/`. A `claude` started with a custom
  /// `CLAUDE_CONFIG_DIR` looks for its `/ide` lock under that dir, not under
  /// `~/.claude/ide`, so without this its IDE bridge can't reach clide. Lazy:
  /// main.dart passes a closure resolved against the (post-boot) AccountRegistry.
  final String? Function()? boundConfigDir;

  /// Bind host. localhost-only by default per D-73 (no remote
  /// access; the threat model matches D-71's `0600`).
  final String bindHost;

  /// Bind port. 0 ⇒ kernel picks a random free port.
  final int bindPort;

  HttpServer? _http;

  /// Every discovery-lock path this process has written — the default `ide/`
  /// dir plus any bound-account `ide/` dirs. Reconciled by [syncDiscoveryLocks];
  /// all are removed on [stop] so no orphan locks survive (T-479).
  final Set<String> _lockFiles = {};
  int? _port;
  String? _authToken;
  final Map<String, _McpSession> _sessions = {};
  int _sessionCounter = 0;

  bool get isRunning => _http != null;
  int? get port => _port;

  String get _defaultIdeDir => discoveryDirOverride ?? '${Platform.environment['HOME'] ?? '/tmp'}/.claude/ide';
  String get _defaultLockPath => '$_defaultIdeDir/$pid.lock';

  /// The lock in the default `~/.claude/ide` dir (the one Claude finds without
  /// `CLAUDE_CONFIG_DIR`). Null until [start] writes it.
  String? get lockFilePath => _lockFiles.contains(_defaultLockPath) ? _defaultLockPath : null;

  /// The per-start bearer token clients must present in [kMcpAuthHeader].
  /// Published to legitimate clients via the 0600 lock file only.
  String? get authToken => _authToken;

  Future<void> start() async {
    if (isRunning) return;
    final server = await HttpServer.bind(bindHost, bindPort);
    _http = server;
    _port = server.port;
    _authToken = _generateToken();
    await syncDiscoveryLocks();
    server.listen(
      _route,
      onError: (Object e, StackTrace st) {
        log.warn('mcp', 'http error: $e');
      },
    );
    log.info('mcp', 'MCP/SSE listening at http://$bindHost:${server.port} (workspace: $workspaceRoot)');
  }

  Future<void> stop() async {
    final s = _http;
    if (s == null) return;
    _http = null;
    _port = null;
    for (final session in List<_McpSession>.from(_sessions.values)) {
      await session.close();
    }
    _sessions.clear();
    await s.close(force: true);
    for (final lock in _lockFiles) {
      _deleteLock(lock);
    }
    _lockFiles.clear();
  }

  // -- routing --------------------------------------------------------------

  Future<void> _route(HttpRequest req) async {
    // Token gate first, on every path (T-362). Without it, any local
    // process could drive the entire dispatcher D-71's 0600 socket guards.
    if (req.headers.value(kMcpAuthHeader) != _authToken) {
      req.response.statusCode = HttpStatus.unauthorized;
      await req.response.close();
      return;
    }
    final path = req.uri.path;
    if (path == '/sse' && req.method == 'GET') {
      await _openSseStream(req);
      return;
    }
    if (path == '/messages' && req.method == 'POST') {
      await _receivePost(req);
      return;
    }
    req.response.statusCode = HttpStatus.notFound;
    await req.response.close();
  }

  Future<void> _openSseStream(HttpRequest req) async {
    final sessionId = 's${_sessionCounter++}';
    req.response.headers.contentType = ContentType('text', 'event-stream');
    req.response.headers.set('Cache-Control', 'no-cache');
    req.response.headers.set('Connection', 'keep-alive');
    req.response.headers.set('X-Accel-Buffering', 'no');
    req.response.bufferOutput = false;
    final session = _McpSession(sessionId, req.response);
    _sessions[sessionId] = session;
    // Initial endpoint event tells the client where to POST.
    req.response.write('event: endpoint\n');
    req.response.write('data: /messages?sessionId=$sessionId\n\n');
    // Keep alive until the client closes.
    try {
      await req.response.done;
    } catch (_) {}
    session.closed = true;
    _sessions.remove(sessionId);
  }

  Future<void> _receivePost(HttpRequest req) async {
    final sessionId = req.uri.queryParameters['sessionId'];
    final session = sessionId == null ? null : _sessions[sessionId];
    if (session == null) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    final body = await utf8.decodeStream(req);
    Map<String, Object?>? msg;
    try {
      msg = jsonDecode(body) as Map<String, Object?>;
    } catch (_) {
      req.response.statusCode = HttpStatus.badRequest;
      await req.response.close();
      return;
    }
    // Acknowledge the POST immediately; the actual JSON-RPC reply
    // travels back over the SSE channel.
    req.response.statusCode = HttpStatus.accepted;
    await req.response.close();
    final reply = await _dispatchJsonRpc(msg);
    if (reply != null) session.send(reply);
  }

  // -- JSON-RPC handlers ---------------------------------------------------

  Future<Map<String, Object?>?> _dispatchJsonRpc(Map<String, Object?> msg) async {
    final id = msg['id'];
    final method = msg['method'] as String?;
    if (method == null) {
      // Notifications without a method are ignored.
      return null;
    }
    try {
      final result = await _handleMethod(method, msg['params'] as Map<String, Object?>?);
      if (id == null) return null; // notification — no reply
      return {'jsonrpc': '2.0', 'id': id, 'result': result};
    } catch (e, st) {
      log.warn('mcp', 'method $method threw: $e');
      log.debug('mcp', '$st');
      return {
        'jsonrpc': '2.0',
        'id': id,
        'error': {'code': -32000, 'message': '$e'},
      };
    }
  }

  Future<Object?> _handleMethod(String method, Map<String, Object?>? params) async {
    switch (method) {
      case 'initialize':
        return {
          'protocolVersion': '2024-11-05',
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': {'name': 'clide', 'version': 'dev'},
        };
      case 'tools/list':
        return {
          'tools': [
            // The `/ide` minimum (D-68). Both still stubbed — getDiagnostics
            // and executeCode (Jupyter) are deferred follow-ups; T-225 wires
            // the clide command surface below.
            {
              'name': 'mcp__ide__getDiagnostics',
              'description': 'Return diagnostics from the open editor (stubbed).',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'uri': {'type': 'string'},
                },
              },
            },
            {
              'name': 'mcp__ide__executeCode',
              'description': 'Execute a code cell in clide (stubbed; clide has no eval surface yet).',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'code': {'type': 'string'},
                },
              },
            },
            // The full clide surface, generated from the command registry.
            ...?dispatcher?.mcpTools(),
          ],
        };
      case 'tools/call':
        final name = (params?['name'] as String?) ?? '';
        if (name.startsWith(_clideToolPrefix)) {
          return _callClideTool(name, params);
        }
        switch (name) {
          case 'mcp__ide__getDiagnostics':
            return {
              'content': [
                {'type': 'text', 'text': '[]'},
              ],
            };
          case 'mcp__ide__executeCode':
            return {
              'content': [
                {'type': 'text', 'text': 'executeCode is not implemented in clide today.'},
              ],
              'isError': true,
            };
          default:
            throw StateError('unknown tool: $name');
        }
      default:
        throw StateError('unknown method: $method');
    }
  }

  /// Run a `mcp__clide__<cmd>` tool by dispatching the underlying command
  /// (D-86). The MCP `arguments` object maps straight to the request's named
  /// args — the dispatcher's D-74 schema normalises/validates them. The
  /// response is rendered as MCP tool content: `data` as JSON text on success,
  /// the error message with `isError: true` on failure.
  Future<Object?> _callClideTool(String name, Map<String, Object?>? params) async {
    final d = dispatcher;
    if (d == null) {
      return {
        'content': [
          {'type': 'text', 'text': 'clide command surface is not available'},
        ],
        'isError': true,
      };
    }
    final cmd = name.substring(_clideToolPrefix.length);
    final args = (params?['arguments'] as Map?)?.cast<String, Object?>() ?? const {};
    final resp = await d.dispatch(IpcRequest(id: 'mcp', cmd: cmd, args: args));
    if (resp.ok) {
      return {
        'content': [
          {'type': 'text', 'text': jsonEncode(resp.data)},
        ],
      };
    }
    return {
      'content': [
        {'type': 'text', 'text': resp.error?.message ?? 'command failed'},
      ],
      'isError': true,
    };
  }

  // -- discovery file -------------------------------------------------------

  /// The `ide/` dirs a discovery lock should currently live in: the default
  /// `~/.claude/ide` always, plus the bound account's `<dir>/ide` when this
  /// workspace is bound to a non-default account (T-479). Deduped, order-stable.
  List<String> _activeIdeDirs() {
    final dirs = <String>[_defaultIdeDir];
    final bound = boundConfigDir?.call();
    if (bound != null && bound.isNotEmpty) {
      final accountIde = '$bound/ide';
      if (!dirs.contains(accountIde)) dirs.add(accountIde);
    }
    return dirs;
  }

  /// Reconcile the on-disk discovery locks with the currently-active `ide/`
  /// dirs (T-479): write a lock into each active dir, and remove any this
  /// process wrote into a dir that is no longer active. Called on [start] and
  /// whenever a per-repo account binding changes. No-op while not running.
  Future<void> syncDiscoveryLocks() async {
    if (!isRunning) return;
    final want = {for (final d in _activeIdeDirs()) '$d/$pid.lock'};
    for (final path in _lockFiles.difference(want).toList()) {
      _deleteLock(path);
      _lockFiles.remove(path);
    }
    for (final path in want.difference(_lockFiles).toList()) {
      await _writeLockAt(path);
      _lockFiles.add(path);
    }
  }

  /// Write (or overwrite) the discovery lock at [path] — same content in every
  /// dir — creating the `ide/` parent and 0600-scoping the file (T-362).
  Future<void> _writeLockAt(String path) async {
    final dirHandle = File(path).parent;
    if (!dirHandle.existsSync()) {
      dirHandle.createSync(recursive: true);
    }
    final body = jsonEncode({
      'pid': pid,
      'workspace': workspaceRoot,
      'transport': 'sse',
      'url': 'http://$bindHost:$_port/sse',
      // Claude Code's /ide lock format carries the bearer token here; the
      // 0600 below is what scopes it to this user (T-362).
      'authToken': _authToken,
    });
    File(path).writeAsStringSync(body);
    try {
      await _chmod(path, '600');
    } catch (e) {
      // Not fatal like the socket's chmod (D-71): the lock lives under
      // ~/.claude which the home-dir perms usually already protect. But say so.
      log.warn('mcp', 'chmod 600 on $path failed: $e — the auth token may be readable by other local users');
    }
  }

  void _deleteLock(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (e) {
      log.warn('mcp', 'failed to unlink lock $path: $e');
    }
  }

  /// 32 bytes of CSPRNG entropy, base64url — the per-start bearer token.
  static String _generateToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// `chmod` via `chmod(1)` — dart:io doesn't expose mode bits (same
  /// approach as the unix-socket server, D-71).
  static Future<void> _chmod(String path, String octal) async {
    final r = await Process.run('chmod', [octal, path]);
    if (r.exitCode != 0) {
      throw ProcessException('chmod', [octal, path], r.stderr.toString(), r.exitCode);
    }
  }
}
