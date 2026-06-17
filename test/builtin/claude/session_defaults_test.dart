import 'dart:io';

import 'package:clide/builtin/claude/src/session_defaults.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory appDir;
  late SettingsStore settings;

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('clide_cd_');
    settings = SettingsStore(appDir: appDir);
    await settings.load();
  });
  tearDown(() async {
    settings.dispose();
    await appDir.delete(recursive: true);
  });

  group('defaultEffortFlag (T-457)', () {
    test('null when unset — let the CLI default stand', () {
      expect(defaultEffortFlag(settings), isNull);
    });

    test("null for the 'default' sentinel", () async {
      await settings.set(kDefaultEffortKey, 'default');
      expect(defaultEffortFlag(settings), isNull);
    });

    test('returns a concrete level', () async {
      await settings.set(kDefaultEffortKey, 'high');
      expect(defaultEffortFlag(settings), 'high');
    });
  });
}
