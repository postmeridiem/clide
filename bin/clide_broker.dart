/// The web broker (D-117): Flutter-free, compiled with
/// `dart compile exe` (`make broker`).
library;

import 'dart:io';

import 'package:clide/src/broker/cli.dart';

Future<void> main(List<String> args) async {
  final code = await runBrokerCli(args, environment: Platform.environment, out: stdout, err: stderr);
  await Future.wait([stdout.flush(), stderr.flush()]);
  exit(code);
}
