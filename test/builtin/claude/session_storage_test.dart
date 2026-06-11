import 'dart:io';

import 'package:clide/builtin/claude/src/session_index.dart';
import 'package:clide/builtin/claude/src/session_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  SessionSummary session(String id, int bytes) => SessionSummary(id: id, modified: DateTime.now(), firstUser: 'f', lastUser: 'l', sizeBytes: bytes);

  testWidgets('shows the total and a two-click delete that calls the deleter', (tester) async {
    final deleted = <String>[];
    await tester.pumpWidget(
      harness(f, SessionStorageDialog(dir: Directory.systemTemp, sessions: [session('aaa', 2048)], onClose: () {}, deleter: (d, id) async => deleted.add(id))),
    );
    await tester.pump();

    expect(find.text('Session storage  ·  2 KB total'), findsOneWidget);
    expect(find.text('f … l'), findsOneWidget);

    // First click arms the confirm; second click deletes.
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(find.text('Keep'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(deleted, ['aaa']);
    expect(find.text('f … l'), findsNothing); // row removed
  });

  testWidgets('Escape closes', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      harness(f, SessionStorageDialog(dir: Directory.systemTemp, sessions: [session('aaa', 1024)], onClose: () => closed = true, deleter: (_, _) async {})),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, isTrue);
  });

  testWidgets('empty list shows a message', (tester) async {
    await tester.pumpWidget(harness(f, SessionStorageDialog(dir: Directory.systemTemp, sessions: const [], onClose: () {}, deleter: (_, _) async {})));
    await tester.pump();
    expect(find.text('No sessions found for this workspace.'), findsOneWidget);
  });
}
