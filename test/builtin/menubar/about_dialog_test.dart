/// T-47 P1: the About box "Check for updates" button. The check runs ONLY on
/// the explicit tap (never on open — POLICY/D-64), and surfaces the result
/// inline: up-to-date, available (with a release link), or a clear error.
library;

import 'dart:io' show Platform;

import 'package:clide/builtin/menubar/src/about_dialog.dart';
import 'package:clide/kernel/kernel.dart' show DaemonEvent;
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/schema_v1.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  Future<void> pump(WidgetTester tester, Future<String> Function(Uri) fetch) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(harness(f, AboutDialog(onDismiss: () {}, updateFetch: fetch)));
    await tester.pump();
  }

  testWidgets('does not fetch until the user taps Check for updates (no network on open)', (tester) async {
    var calls = 0;
    await pump(tester, (_) async {
      calls++;
      return '{"tag_name":"v2.9.0","html_url":"https://x/r"}';
    });
    expect(calls, 0, reason: 'opening the About box must not touch the network');

    await tester.tap(find.text('Check for updates'));
    await pumpAsync(tester);
    expect(calls, 1);
  });

  testWidgets('shows an update-available link when a newer release exists', (tester) async {
    await pump(tester, (_) async => '{"tag_name":"v99.0.0","html_url":"https://github.com/postmeridiem/clide/releases/v99.0.0"}');
    await tester.tap(find.text('Check for updates'));
    await pumpAsync(tester);
    expect(find.textContaining('99.0.0'), findsOneWidget);
  });

  testWidgets('shows up-to-date when the latest release is not newer', (tester) async {
    await pump(tester, (_) async => '{"tag_name":"v0.0.1","html_url":"https://x/r"}');
    await tester.tap(find.text('Check for updates'));
    await pumpAsync(tester);
    expect(find.textContaining('latest version'), findsOneWidget);
  });

  // T-621: an update with an installable bundle offers Install, which goes
  // through the `app.update` verb and renders its progress events.
  group('install', () {
    const withBundle =
        '{"tag_name":"v99.0.0","html_url":"https://x/r","assets":[{"name":"clide-linux-x64-99.0.0.tar.gz",'
        '"browser_download_url":"https://x/t.tar.gz","digest":"sha256:abc","size":1}]}';

    testWidgets('no installable bundle, no Install button', (tester) async {
      await pump(tester, (_) async => '{"tag_name":"v99.0.0","html_url":"https://x/r"}');
      await tester.tap(find.text('Check for updates'));
      await pumpAsync(tester);
      expect(find.byKey(const Key('about-install')), findsNothing);
    });

    testWidgets('Install asks app.update to install, shows progress, and surfaces a failure', (tester) async {
      Map<String, Object?>? asked;
      f.ipc.stub('app.update', (args) async {
        asked = args;
        f.services.events.emit(DaemonEvent(subsystem: 'app', kind: 'app.update', data: const {'phase': 'verifying'}, ts: DateTime.now().toUtc()));
        return IpcResponse.err(
          id: '1',
          error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'checksum mismatch'),
        );
      });
      await pump(tester, (_) async => withBundle);
      await tester.tap(find.text('Check for updates'));
      await pumpAsync(tester);

      await tester.tap(find.byKey(const Key('about-install')));
      await pumpAsync(tester);
      expect(asked, {'install': true});
      expect(find.textContaining('Update failed'), findsOneWidget);
      expect(find.textContaining('checksum mismatch'), findsOneWidget);
      expect(find.byKey(const Key('about-install')), findsOneWidget, reason: 'can be retried');
    });

    testWidgets('while installing, the phase shows and both buttons step aside', (tester) async {
      f.ipc.stub('app.update', (args) async {
        f.services.events.emit(
          DaemonEvent(subsystem: 'app', kind: 'app.update', data: const {'phase': 'downloading', 'fraction': 0.5}, ts: DateTime.now().toUtc()),
        );
        f.services.events.emit(DaemonEvent(subsystem: 'app', kind: 'app.update', data: const {'phase': 'restarting'}, ts: DateTime.now().toUtc()));
        return IpcResponse.ok(id: '1', data: const {'restarting': true});
      });
      await pump(tester, (_) async => withBundle);
      await tester.tap(find.text('Check for updates'));
      await pumpAsync(tester);
      await tester.tap(find.byKey(const Key('about-install')));
      await pumpAsync(tester);
      expect(find.text('Restarting windows…'), findsOneWidget);
      expect(find.byKey(const Key('about-install')), findsNothing);
    });
  }, skip: !Platform.isLinux ? 'releases only publish a Linux bundle' : false);

  testWidgets('surfaces a clear error when the check fails', (tester) async {
    await pump(tester, (_) => Future.error('offline'));
    await tester.tap(find.text('Check for updates'));
    await pumpAsync(tester);
    expect(find.textContaining("Couldn't check"), findsOneWidget);
  });
}
