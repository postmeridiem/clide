/// Widget tests for DiffView focus (T-233): an injected controller renders its
/// diffs, and focusing a file highlights its header with the focus accent.
library;

import 'package:clide/builtin/diff/src/diff_controller.dart';
import 'package:clide/builtin/diff/src/diff_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ipc.dart';
import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);
Map<String, Object?> _file(String path) => {'path': path, 'hunks': const []};

ClideText _header(WidgetTester tester, String path) => tester.widget<ClideText>(find.byWidgetPredicate((w) => w is ClideText && w.data == path));

void main() {
  late KernelFixture f;
  late DaemonBus bus;
  late FakeDaemonClient ipc;
  late DiffController c;

  setUp(() async {
    f = await KernelFixture.create();
    bus = DaemonBus();
    ipc = FakeDaemonClient(log: Logger(), events: bus);
    ipc.stub(
        'git.diff',
        (_) async => _ok({
              'diffs': [_file('lib/a.dart'), _file('lib/b.dart')]
            }));
    c = DiffController(ipc: ipc, events: bus);
  });

  tearDown(() async {
    c.dispose();
    await bus.dispose();
    f.dispose();
  });

  testWidgets('renders the injected controller\'s diffs', (tester) async {
    await c.load();
    await tester.pumpWidget(harness(f, DiffView(controller: c)));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is ClideText && w.data == 'lib/a.dart'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is ClideText && w.data == 'lib/b.dart'), findsOneWidget);
  });

  testWidgets('focusing a file highlights its header with the focus accent', (tester) async {
    await c.load();
    await tester.pumpWidget(harness(f, DiffView(controller: c)));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(DiffView));
    final tokens = ClideTheme.of(ctx).surface;
    // Before focus: header uses the plain panel-header foreground.
    expect(_header(tester, 'lib/b.dart').color, tokens.panelHeaderForeground);

    c.focus('lib/b.dart');
    await tester.pumpAndSettle();

    // After focus: the targeted file's header switches to the focus accent.
    expect(_header(tester, 'lib/b.dart').color, tokens.globalFocus);
    // The other file stays unhighlighted.
    expect(_header(tester, 'lib/a.dart').color, tokens.panelHeaderForeground);
  });
}
