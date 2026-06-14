/// T-130 — MCP server over HTTP+SSE (per D-73). Tests the discovery
/// file shape, JSON-RPC round-trip for initialize / tools/list /
/// tools/call, and end-of-session cleanup.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/src/ipc/mcp_server.dart';
import 'package:test/test.dart';

Logger _silent() => Logger(minLevel: LogLevel.error, sinks: const []);

void main() {
  late Directory discoveryDir;
  late McpServer server;

  setUp(() async {
    discoveryDir = await Directory.systemTemp.createTemp('clide-mcp-disc-');
    server = McpServer(workspaceRoot: '/var/mnt/test/clide-fixture', log: _silent(), discoveryDirOverride: discoveryDir.path);
    await server.start();
  });

  tearDown(() async {
    try {
      await server.stop();
    } catch (_) {}
    if (discoveryDir.existsSync()) discoveryDir.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> openSse({String? token}) async {
    final client = HttpClient();
    addTearDown(client.close);
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/sse'));
    final t = token ?? server.authToken;
    if (t != null) req.headers.set(kMcpAuthHeader, t);
    return req.close();
  }

  Future<(String sessionId, Stream<String> dataLines)> connectAndCaptureEndpoint() async {
    final resp = await openSse();
    // Broadcast so multiple consumers in a test can subscribe.
    final dataLines = resp
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data: '))
        .map((line) => line.substring(6))
        .asBroadcastStream();
    final endpoint = Completer<String>();
    final endpointSub = dataLines.listen((data) {
      final match = RegExp(r'sessionId=([\w-]+)').firstMatch(data);
      if (match != null && !endpoint.isCompleted) {
        endpoint.complete(match.group(1)!);
      }
    });
    final id = await endpoint.future.timeout(const Duration(seconds: 2));
    await endpointSub.cancel();
    return (id, dataLines);
  }

  Future<Map<String, Object?>> post(String sessionId, Map<String, Object?> body) async {
    final client = HttpClient();
    addTearDown(client.close);
    final req = await client.postUrl(Uri.parse('http://127.0.0.1:${server.port}/messages?sessionId=$sessionId'));
    req.headers.contentType = ContentType.json;
    req.headers.set(kMcpAuthHeader, server.authToken!);
    req.write(jsonEncode(body));
    final resp = await req.close();
    expect(resp.statusCode, HttpStatus.accepted);
    return body;
  }

  group('McpServer (T-130) lifecycle', () {
    test('start binds a port and writes a discovery lock file', () async {
      expect(server.isRunning, isTrue);
      expect(server.port, greaterThan(0));
      expect(server.lockFilePath, isNotNull);
      final lock = File(server.lockFilePath!);
      expect(lock.existsSync(), isTrue);
      final payload = jsonDecode(lock.readAsStringSync()) as Map<String, Object?>;
      expect(payload['workspace'], '/var/mnt/test/clide-fixture');
      expect(payload['transport'], 'sse');
      expect(payload['url'], startsWith('http://127.0.0.1:${server.port}'));
    });

    test('stop removes the lock file', () async {
      final lock = server.lockFilePath!;
      await server.stop();
      expect(File(lock).existsSync(), isFalse);
    });

    test('unknown path returns 404', () async {
      final client = HttpClient();
      addTearDown(client.close);
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/no-such-thing'));
      req.headers.set(kMcpAuthHeader, server.authToken!);
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.notFound);
    });
  });

  // T-362: D-71's "another user on this host must not drive my IDE" is
  // enforced with 0600 on the unix socket — the HTTP port must not bypass it.
  group('McpServer (T-362) auth token', () {
    test('the lock file publishes the auth token, mode 600', () async {
      final lock = File(server.lockFilePath!);
      final payload = jsonDecode(lock.readAsStringSync()) as Map<String, Object?>;
      expect(payload['authToken'], server.authToken);
      expect((server.authToken ?? '').length, greaterThanOrEqualTo(32));
      final mode = lock.statSync().mode & 0xFFF;
      expect(mode, 0x180, reason: 'lock file must be 0600 — it carries the token');
    });

    test('a request without the token is rejected with 401', () async {
      final client = HttpClient();
      addTearDown(client.close);
      final sse = await (await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/sse'))).close();
      expect(sse.statusCode, HttpStatus.unauthorized);

      final post = await client.postUrl(Uri.parse('http://127.0.0.1:${server.port}/messages?sessionId=s0'));
      post.write('{"jsonrpc":"2.0","id":1,"method":"initialize"}');
      final resp = await post.close();
      expect(resp.statusCode, HttpStatus.unauthorized);
    });

    test('a request with a wrong token is rejected with 401', () async {
      final resp = await openSse(token: 'not-the-token');
      expect(resp.statusCode, HttpStatus.unauthorized);
    });

    test('the token rotates per start', () async {
      final first = server.authToken;
      await server.stop();
      await server.start();
      expect(server.authToken, isNot(first));
    });
  });

  group('McpServer (T-130) JSON-RPC', () {
    test('SSE opens with an endpoint event carrying the session id', () async {
      final (sessionId, events) = await connectAndCaptureEndpoint();
      expect(sessionId, isNotEmpty);
    });

    test('initialize returns server info + tool capability', () async {
      final (sessionId, events) = await connectAndCaptureEndpoint();
      final replyFuture = events.firstWhere((s) => s.contains('"id":1'));
      await post(sessionId, {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize'});
      final reply = jsonDecode(await replyFuture.timeout(const Duration(seconds: 2))) as Map<String, Object?>;
      expect(reply['id'], 1);
      final result = reply['result'] as Map<String, Object?>;
      expect((result['serverInfo'] as Map)['name'], 'clide');
      expect((result['capabilities'] as Map).containsKey('tools'), isTrue);
    });

    test('tools/list lists both /ide tools per D-68', () async {
      final (sessionId, events) = await connectAndCaptureEndpoint();
      final replyFuture = events.firstWhere((s) => s.contains('"id":2'));
      await post(sessionId, {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'});
      final reply = jsonDecode(await replyFuture.timeout(const Duration(seconds: 2))) as Map<String, Object?>;
      final tools = ((reply['result'] as Map)['tools'] as List).cast<Map<String, Object?>>();
      final names = tools.map((t) => t['name']).toSet();
      expect(names, containsAll(['mcp__ide__getDiagnostics', 'mcp__ide__executeCode']));
    });

    test('tools/call mcp__ide__getDiagnostics returns the stub content', () async {
      final (sessionId, events) = await connectAndCaptureEndpoint();
      final replyFuture = events.firstWhere((s) => s.contains('"id":3'));
      await post(sessionId, {
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': {'name': 'mcp__ide__getDiagnostics', 'arguments': {}},
      });
      final reply = jsonDecode(await replyFuture.timeout(const Duration(seconds: 2))) as Map<String, Object?>;
      final result = reply['result'] as Map<String, Object?>;
      final content = (result['content'] as List).cast<Map<String, Object?>>();
      expect(content.first['type'], 'text');
      // Stub returns []
      expect(content.first['text'], '[]');
    });

    test('tools/call mcp__ide__executeCode flags isError (stubbed)', () async {
      final (sessionId, events) = await connectAndCaptureEndpoint();
      final replyFuture = events.firstWhere((s) => s.contains('"id":4'));
      await post(sessionId, {
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'tools/call',
        'params': {
          'name': 'mcp__ide__executeCode',
          'arguments': {'code': 'print(1)'},
        },
      });
      final reply = jsonDecode(await replyFuture.timeout(const Duration(seconds: 2))) as Map<String, Object?>;
      final result = reply['result'] as Map<String, Object?>;
      expect(result['isError'], isTrue);
    });

    test('unknown method surfaces as a JSON-RPC error', () async {
      final (sessionId, events) = await connectAndCaptureEndpoint();
      final replyFuture = events.firstWhere((s) => s.contains('"id":5'));
      await post(sessionId, {'jsonrpc': '2.0', 'id': 5, 'method': 'no.such.method'});
      final reply = jsonDecode(await replyFuture.timeout(const Duration(seconds: 2))) as Map<String, Object?>;
      expect(reply['error'], isNotNull);
    });

    test('POST with unknown sessionId returns 404', () async {
      final client = HttpClient();
      addTearDown(client.close);
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:${server.port}/messages?sessionId=ghost'));
      req.headers.contentType = ContentType.json;
      req.headers.set(kMcpAuthHeader, server.authToken!);
      req.write('{"jsonrpc":"2.0","id":1,"method":"initialize"}');
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.notFound);
    });

    test('POST with malformed JSON returns 400', () async {
      final (sessionId, events) = await connectAndCaptureEndpoint();
      final client = HttpClient();
      addTearDown(client.close);
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:${server.port}/messages?sessionId=$sessionId'));
      req.headers.contentType = ContentType.json;
      req.headers.set(kMcpAuthHeader, server.authToken!);
      req.write('{not json');
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.badRequest);
    });

    test('notification (no id) is processed without a reply', () async {
      final (sessionId, events) = await connectAndCaptureEndpoint();
      final lines = <String>[];
      final sub = events.listen(lines.add);
      addTearDown(sub.cancel);
      await post(sessionId, {'jsonrpc': '2.0', 'method': 'initialize'});
      // Give the server a tick — we should NOT see a reply.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(lines, isEmpty);
    });
  });

  group('McpServer (T-225) clide tool surface', () {
    late Directory disc;
    late McpServer srv;

    setUp(() async {
      disc = await Directory.systemTemp.createTemp('clide-mcp-clide-');
      final dispatcher = DaemonDispatcher();
      dispatcher.register('echo', (req) async => IpcResponse.ok(id: req.id, data: {'echo': req.args['text']}));
      // A poor MCP fit — withheld from the tool surface (D-86).
      dispatcher.register('pane.tail', (req) async => IpcResponse.ok(id: req.id, data: const {}), mcpExpose: false);
      srv = McpServer(workspaceRoot: '/x', log: _silent(), discoveryDirOverride: disc.path, dispatcher: dispatcher);
      await srv.start();
    });

    tearDown(() async {
      try {
        await srv.stop();
      } catch (_) {}
      if (disc.existsSync()) disc.deleteSync(recursive: true);
    });

    Future<(String, Stream<String>)> connect() async {
      final client = HttpClient();
      addTearDown(client.close);
      final sseReq = await client.getUrl(Uri.parse('http://127.0.0.1:${srv.port}/sse'));
      sseReq.headers.set(kMcpAuthHeader, srv.authToken!);
      final resp = await sseReq.close();
      final dataLines = resp
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((l) => l.startsWith('data: '))
          .map((l) => l.substring(6))
          .asBroadcastStream();
      final endpoint = Completer<String>();
      final sub = dataLines.listen((d) {
        final m = RegExp(r'sessionId=([\w-]+)').firstMatch(d);
        if (m != null && !endpoint.isCompleted) endpoint.complete(m.group(1)!);
      });
      final id = await endpoint.future.timeout(const Duration(seconds: 2));
      await sub.cancel();
      return (id, dataLines);
    }

    Future<void> post(String sid, Map<String, Object?> body) async {
      final client = HttpClient();
      addTearDown(client.close);
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:${srv.port}/messages?sessionId=$sid'));
      req.headers.contentType = ContentType.json;
      req.headers.set(kMcpAuthHeader, srv.authToken!);
      req.write(jsonEncode(body));
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.accepted);
    }

    test('tools/list adds generated mcp__clide__ tools alongside the /ide pair', () async {
      final (sid, events) = await connect();
      final replyFuture = events.firstWhere((s) => s.contains('"id":10'));
      await post(sid, {'jsonrpc': '2.0', 'id': 10, 'method': 'tools/list'});
      final reply = jsonDecode(await replyFuture.timeout(const Duration(seconds: 2))) as Map<String, Object?>;
      final names = ((reply['result'] as Map)['tools'] as List).map((t) => (t as Map)['name']).toSet();
      expect(names, containsAll(['mcp__ide__getDiagnostics', 'mcp__clide__echo', 'mcp__clide__ping']));
      // The opt-out command is withheld.
      expect(names.contains('mcp__clide__pane.tail'), isFalse);
    });

    test('tools/call routes mcp__clide__ tools to the dispatcher', () async {
      final (sid, events) = await connect();
      final replyFuture = events.firstWhere((s) => s.contains('"id":11'));
      await post(sid, {
        'jsonrpc': '2.0',
        'id': 11,
        'method': 'tools/call',
        'params': {
          'name': 'mcp__clide__echo',
          'arguments': {'text': 'hi'},
        },
      });
      final reply = jsonDecode(await replyFuture.timeout(const Duration(seconds: 2))) as Map<String, Object?>;
      final content = ((reply['result'] as Map)['content'] as List).cast<Map<String, Object?>>();
      expect(jsonDecode(content.first['text'] as String), {'echo': 'hi'});
    });

    test('a failing clide tool surfaces isError with the error message', () async {
      // An unknown command → dispatcher returns a not-found error.
      final (sid, events) = await connect();
      final replyFuture = events.firstWhere((s) => s.contains('"id":12'));
      await post(sid, {
        'jsonrpc': '2.0',
        'id': 12,
        'method': 'tools/call',
        'params': {'name': 'mcp__clide__nope.verb', 'arguments': const {}},
      });
      final reply = jsonDecode(await replyFuture.timeout(const Duration(seconds: 2))) as Map<String, Object?>;
      final result = reply['result'] as Map<String, Object?>;
      expect(result['isError'], isTrue);
      expect((result['content'] as List).first['text'], contains('unknown command'));
    });
  });

  test('calling a clide tool with no dispatcher wired surfaces isError', () async {
    final disc = await Directory.systemTemp.createTemp('clide-mcp-nodisp-');
    final srv = McpServer(workspaceRoot: '/x', log: _silent(), discoveryDirOverride: disc.path);
    await srv.start();
    addTearDown(() async {
      await srv.stop();
      if (disc.existsSync()) disc.deleteSync(recursive: true);
    });
    final client = HttpClient();
    addTearDown(client.close);
    final sseReq = await client.getUrl(Uri.parse('http://127.0.0.1:${srv.port}/sse'));
    sseReq.headers.set(kMcpAuthHeader, srv.authToken!);
    final resp = await sseReq.close();
    final data = resp
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((l) => l.startsWith('data: '))
        .map((l) => l.substring(6))
        .asBroadcastStream();
    final ep = Completer<String>();
    final sub = data.listen((d) {
      final m = RegExp(r'sessionId=([\w-]+)').firstMatch(d);
      if (m != null && !ep.isCompleted) ep.complete(m.group(1)!);
    });
    final sid = await ep.future.timeout(const Duration(seconds: 2));
    await sub.cancel();
    final replyFuture = data.firstWhere((s) => s.contains('"id":13'));
    final post = await client.postUrl(Uri.parse('http://127.0.0.1:${srv.port}/messages?sessionId=$sid'));
    post.headers.contentType = ContentType.json;
    post.headers.set(kMcpAuthHeader, srv.authToken!);
    post.write(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': 13,
        'method': 'tools/call',
        'params': {'name': 'mcp__clide__echo', 'arguments': const {}},
      }),
    );
    await post.close();
    final reply = jsonDecode(await replyFuture.timeout(const Duration(seconds: 2))) as Map<String, Object?>;
    expect((reply['result'] as Map)['isError'], isTrue);
  });
}
