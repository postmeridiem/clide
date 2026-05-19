/// T-130 — MCP server over HTTP+SSE (per D-73). Tests the discovery
/// file shape, JSON-RPC round-trip for initialize / tools/list /
/// tools/call, and end-of-session cleanup.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/src/log.dart';
import 'package:clide/src/ipc/mcp_server.dart';
import 'package:test/test.dart';

Logger _silent() => Logger(minLevel: LogLevel.error, sinks: const []);

void main() {
  late Directory discoveryDir;
  late McpServer server;

  setUp(() async {
    discoveryDir = await Directory.systemTemp.createTemp('clide-mcp-disc-');
    server = McpServer(
      workspaceRoot: '/var/mnt/test/clide-fixture',
      log: _silent(),
      discoveryDirOverride: discoveryDir.path,
    );
    await server.start();
  });

  tearDown(() async {
    try {
      await server.stop();
    } catch (_) {}
    if (discoveryDir.existsSync()) discoveryDir.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> openSse() async {
    final client = HttpClient();
    addTearDown(client.close);
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/sse'));
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
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.notFound);
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
          'arguments': {'code': 'print(1)'}
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
}
