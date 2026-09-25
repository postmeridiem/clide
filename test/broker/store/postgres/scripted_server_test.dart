import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import 'scripted_server.dart';

/// The scripted server itself. Connection tests make the client drop the
/// connection in the middle of a script, so the server has to take that as
/// the client leaving, not as an error.
void main() {
  test('a script that writes after the client dropped the connection ends cleanly', () async {
    final finished = Completer<void>();
    final server = await ScriptedServer.start((c) async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        c.ready();
      }
      await c.untilClosed();
      finished.complete();
    });
    addTearDown(server.close);
    (await Socket.connect(InternetAddress.loopbackIPv4, server.port)).destroy();
    await finished.future;
    expect(server.errors, isEmpty);
  });
}
