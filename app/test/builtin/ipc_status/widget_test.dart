import 'dart:ui';

import 'package:clide_app/builtin/ipc_status/ipc_status.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('IpcStatusExtension', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create(
        i18nCatalogs: {
          'builtin.ipc-status': {
            const Locale('en', 'US'): const {
              'connected': {'translation': 'connected'},
              'connected.hint': {'translation': 'daemon reachable'},
              'disconnected': {'translation': 'disconnected'},
              'disconnected.hint': {'translation': 'daemon down'},
            },
          },
        },
      );
    });

    tearDown(() async => f.dispose());

    test('contributes a statusbar item', () async {
      f.services.extensions.register(IpcStatusExtension());
      await f.services.extensions.activateAll();
      final items = f.services.panels
          .contributionsFor(Slots.statusbar)
          .whereType<StatusItemContribution>()
          .toList();
      expect(items, hasLength(1));
      expect(items.first.priority, 100);
    });

    testWidgets('renders "disconnected" label until connected', (tester) async {
      await tester.pumpWidget(
        harness(f, IpcStatusItem(ipc: f.services.ipc)),
      );
      expect(find.text('disconnected'), findsOneWidget);
    });

    testWidgets('flips to "connected" when the client reports connected',
        (tester) async {
      await tester.pumpWidget(
        harness(f, IpcStatusItem(ipc: f.services.ipc)),
      );
      f.ipc.setConnected(true);
      await tester.pumpAndSettle();
      expect(find.text('connected'), findsOneWidget);
    });
  });
}
