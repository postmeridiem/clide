/// A stand-in for the workspace host (C4) that the broker can start today. It
/// listens on the workspace's socket (D-70, D-71), greets each connection
/// with the workspace's name, then echoes every byte back, so the broker's
/// session pipe can be tried end to end. The real host replaces it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/ipc/paths.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2 || args.first != '--workspace') {
    stderr.writeln('Usage: clide_stub_host --workspace <dir>');
    exit(64);
  }
  final workspace = args[1];
  if (!Directory(workspace).existsSync()) {
    stderr.writeln('$workspace is not a directory.');
    exit(66);
  }
  // Watched before the socket exists: once the broker sees the socket answer,
  // a SIGTERM must remove it rather than kill the process outright.
  final stopped = Future.any([ProcessSignal.sigterm.watch().first, ProcessSignal.sigint.watch().first]);
  final path = workspaceSocketPath(workspace);
  final directory = Directory(socketDirectory())..createSync(recursive: true);
  await _chmod(directory.path, '700');
  if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound) {
    try {
      (await Socket.connect(InternetAddress(path, type: InternetAddressType.unix), 0)).destroy();
      stderr.writeln('Another host is serving $path.');
      exit(75);
    } on SocketException {
      File(path).deleteSync();
    }
  }
  final server = await ServerSocket.bind(InternetAddress(path, type: InternetAddressType.unix), 0);
  await _chmod(path, '600');
  final name = workspace.split('/').lastWhere((s) => s.isNotEmpty, orElse: () => workspace);
  server.listen((client) {
    // A client that leaves mid-write resets the connection, and dart:io
    // reports that through `done`; it is only the client leaving.
    unawaited(client.done.then<void>((_) {}, onError: (Object _) {}));
    client.add(utf8.encode('clide stub host for $name\n'));
    client.listen(client.add, onDone: client.destroy, onError: (Object _) => client.destroy());
  });
  stdout.writeln('listening for $name on $path');
  await stopped;
  await server.close();
  if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound) File(path).deleteSync();
  exit(0);
}

Future<void> _chmod(String path, String mode) async {
  final r = await Process.run('chmod', [mode, path]);
  if (r.exitCode != 0) throw ProcessException('chmod', [mode, path], r.stderr.toString(), r.exitCode);
}
