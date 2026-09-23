/// Suite-wide setup, run by `flutter test` around every test file.
///
/// Points [socketDirectoryOverride] at a fresh temp dir so no test binds,
/// probes, sweeps or links anything in the real runtime dir — it holds the
/// sockets and `bin/clide` link of any clide running on this machine
/// (T-639). `test/hermetic_test.dart` guards it. Tests run under plain
/// `dart test` (test/ipc, test/daemon, test/pty) don't load this file; they
/// pass an explicit socket dir instead.
library;

import 'dart:async';
import 'dart:io';

import 'package:clide/src/ipc/paths.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final dir = Directory.systemTemp.createTempSync('clide-test-sock-');
  socketDirectoryOverride = dir.path;
  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  await testMain();
}
