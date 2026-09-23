/// Guards the suite-wide isolation set up in `flutter_test_config.dart`
/// (T-639): no flutter test may resolve the real per-user runtime dir, which
/// holds the sockets — and the `bin/clide` link — of any clide running here.
library;

import 'dart:io';

import 'package:clide/src/ipc/paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('socketDirectory() points at a per-run temp dir, not the real one', () {
    final dir = socketDirectory();
    expect(dir, startsWith(Directory.systemTemp.path));
    expect(dir, contains('clide-test-sock-'));
    final xdg = Platform.environment['XDG_RUNTIME_DIR'];
    if (xdg != null && xdg.isNotEmpty) expect(dir, isNot(startsWith(xdg)));
  });
}
