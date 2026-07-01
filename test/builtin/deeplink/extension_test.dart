/// Tests for the deeplink handler's gating (T-56, D-90): an allowlisted link
/// prompts before acting; a non-allowlisted one is rejected with no prompt.
library;

import 'dart:async';

import 'package:clide/builtin/deeplink/deeplink.dart';
import 'package:clide/extension/extension.dart' show CommandContribution;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async {
    f = await KernelFixture.create();
    f.services.extensions.register(DeepLinkExtension());
    await f.services.extensions.activate('builtin.deeplink');
  });
  tearDown(() => f.dispose());

  testWidgets('an allowlisted link prompts before doing anything', (tester) async {
    await tester.pumpWidget(harness(f, const SizedBox()));
    await tester.pump();
    expect(f.services.dialog.isOpen, isFalse);

    // The handler blocks on the confirmation, so don't await it.
    unawaited(f.services.commands.execute('deeplink.invoke', args: ['clide://open?path=/x.dart']));
    await tester.pump();

    expect(f.services.dialog.isOpen, isTrue, reason: 'a confirmation must be shown before acting');
    f.services.dialog.dismiss(false); // decline → cleanup
    await tester.pump();
  });

  testWidgets('a non-allowlisted link is rejected with no prompt', (tester) async {
    await tester.pumpWidget(harness(f, const SizedBox()));
    await tester.pump();

    final r = await f.services.commands.execute('deeplink.invoke', args: ['clide://run?cmd=rm%20-rf']);
    await tester.pump();

    expect(f.services.dialog.isOpen, isFalse, reason: 'no dialog for a rejected link');
    expect(r.data['status'], 'rejected');
  });

  testWidgets('a malformed link is rejected with no prompt', (tester) async {
    await tester.pumpWidget(harness(f, const SizedBox()));
    await tester.pump();

    final r = await f.services.commands.execute('deeplink.invoke', args: ['https://evil.example/open?path=/x']);
    expect(f.services.dialog.isOpen, isFalse);
    expect(r.data['status'], 'rejected');
  });

  testWidgets('confirming an allowlisted link opens the file (T-56)', (tester) async {
    await tester.pumpWidget(harness(f, const SizedBox()));
    await tester.pump();

    final future = f.services.commands.execute('deeplink.invoke', args: ['clide://open?path=/x.dart&line=5']);
    await tester.pump();
    expect(f.services.dialog.isOpen, isTrue);
    f.services.dialog.dismiss(true); // confirm → the handler runs editor.open
    await tester.pumpAndSettle();

    final r = await future;
    expect(r.data['status'], 'opened');
    expect(r.data['path'], '/x.dart');
  });

  test('reports not-activated when invoked before activation', () async {
    final ext = DeepLinkExtension(); // never activated → no context
    final run = (ext.contributions.single as CommandContribution).run;
    expect((await run(['clide://open?path=/x'])).data['status'], 'not-activated');
  });
}
