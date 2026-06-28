/// T-47 P1: the About box "Check for updates" button. The check runs ONLY on
/// the explicit tap (never on open — POLICY/D-64), and surfaces the result
/// inline: up-to-date, available (with a release link), or a clear error.
library;

import 'package:clide/builtin/menubar/src/about_dialog.dart';
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

  testWidgets('surfaces a clear error when the check fails', (tester) async {
    await pump(tester, (_) => Future.error('offline'));
    await tester.tap(find.text('Check for updates'));
    await pumpAsync(tester);
    expect(find.textContaining("Couldn't check"), findsOneWidget);
  });
}
