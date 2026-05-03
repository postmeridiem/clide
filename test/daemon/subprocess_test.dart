import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:test/test.dart';

/// Subprocess-level daemon smoke. Only runs if `bin/clide` has been
/// built (the test skips itself otherwise). This is the release-gate
/// suite — catches signal-handling, socket-unlink, and version-stamp
/// regressions that the in-process test masks.
void main() {
  final binary = File('bin/clide');

  group('bin/clide --daemon (subprocess)', () {
    setUpAll(() {
      if (!binary.existsSync()) {
        markTestSkipped('bin/clide not built; run `make build` first to enable this suite');
      }
    });

    test('starts, responds to ping, exits cleanly on SIGTERM', () async {
      if (!binary.existsSync()) return;

      // Use a fresh socket under a unique temp path so parallel test
      // runs don't collide. The daemon resolves its socket path from
      // XDG_RUNTIME_DIR + USER (see defaultSocketPath()).
      final tmp = await Directory.systemTemp.createTemp('clide_sub_');
      final env = Map<String, String>.from(Platform.environment)
        ..['XDG_RUNTIME_DIR'] = tmp.path
        ..['USER'] = 'daemon';
      final socketPath = '${tmp.path}/clide-daemon.sock';

      final process = await Process.start(
        binary.absolute.path,
        ['--daemon'],
        environment: env,
      );

      // Wait for "listening on ..." on stderr before connecting.
      final ready = Completer<void>();
      final stderrLines = <String>[];
      final sub = process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        stderrLines.add(line);
        if (line.contains('listening')) ready.complete();
      });

      try {
        await ready.future.timeout(const Duration(seconds: 3));

        // Connect and ping
        final sock = await Socket.connect(
          InternetAddress(socketPath, type: InternetAddressType.unix),
          0,
        ).timeout(const Duration(seconds: 3));
        sock.writeln(IpcRequest(id: '1', cmd: 'ping').encode());
        final line = await sock.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).first.timeout(const Duration(seconds: 3));
        await sock.close();
        final resp = IpcMessage.decode(line) as IpcResponse;
        expect(resp.ok, true);
        expect(resp.data['pong'], true);

        // Clean shutdown
        process.kill(ProcessSignal.sigterm);
        final exitCode = await process.exitCode.timeout(const Duration(seconds: 3));
        expect(exitCode, 0);

        // Socket file should be unlinked
        expect(await File(socketPath).exists(), false);
      } finally {
        await sub.cancel();
        try {
          process.kill(ProcessSignal.sigkill);
        } catch (_) {}
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
