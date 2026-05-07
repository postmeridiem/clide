import 'dart:async';

import 'package:alchemist/alchemist.dart';

import '../helpers/golden_harness.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return AlchemistConfig.runWithConfig(
    config: clideGoldenConfig(),
    run: testMain,
  );
}
