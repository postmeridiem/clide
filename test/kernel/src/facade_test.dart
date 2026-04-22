import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  group('KernelServices facade', () {
    test('boot wires every service and they are non-null', () async {
      final f = await KernelFixture.create();
      addTearDown(f.dispose);
      final s = f.services;
      expect(s.log, isNotNull);
      expect(s.events, isNotNull);
      expect(s.settings, isNotNull);
      expect(s.ipc, isNotNull);
      expect(s.theme, isNotNull);
      expect(s.i18n, isNotNull);
      expect(s.panels, isNotNull);
      expect(s.arrangement, isNotNull);
      expect(s.commands, isNotNull);
      expect(s.palette, isNotNull);
      expect(s.keybindings, isNotNull);
      expect(s.clipboard, isNotNull);
      expect(s.files, isNotNull);
      expect(s.notify, isNotNull);
      expect(s.dialog, isNotNull);
      expect(s.tray, isNotNull);
      expect(s.secrets, isNotNull);
      expect(s.os, isNotNull);
      expect(s.net, isNotNull);
      expect(s.focus, isNotNull);
      expect(s.project, isNotNull);
      expect(s.extensions, isNotNull);
    });

    test('i18n is preloaded for the namespaces passed to boot', () async {
      final f = await KernelFixture.create(
        i18nCatalogs: {
          'builtin.welcome': {
            const Locale('en', 'US'): {
              'title': const {'translation': 'clide'},
            },
          },
        },
      );
      addTearDown(f.dispose);
      expect(
        f.services.i18n.string(
          'title',
          namespace: 'builtin.welcome',
          placeholder: '-',
        ),
        'clide',
      );
    });

    test('dispose shuts down IPC + notifiers without throwing', () async {
      final f = await KernelFixture.create();
      await f.dispose();
    });
  });
}
