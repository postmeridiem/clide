/// T-488: the welcome New-project dialog. Tapping "New project…" opens it;
/// filling location + name and pressing Create dispatches `project.new`, opens
/// the result, and announces it on projectCreatedChannel (so the Claude
/// extension can run the account roadblock). Reached through WelcomeView since
/// the dialog is private, wrapped in a DialogHost so kernel.dialog.show renders.
library;

import 'package:clide/builtin/welcome/src/welcome_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/project_commands.dart' show projectCreatedChannel;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

Widget _harness(KernelFixture f, Widget child) => harness(f, DialogHost(router: f.services.dialog, child: child));

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  testWidgets('Create dispatches project.new, opens the result, and announces it', (tester) async {
    Map<String, Object?>? newArgs;
    f.ipc.setConnected(true);
    f.ipc.stub('project.new', (args) async {
      newArgs = args;
      return IpcResponse.ok(id: 'r', data: {'path': '/tmp/np/myapp', 'name': 'myapp'});
    });
    final announced = <Map<String, Object?>>[];
    final sub = f.services.messages.subscribe(channel: projectCreatedChannel).listen((m) => announced.add(m.data));
    addTearDown(sub.cancel);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(f, const WelcomeView()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New project…'));
    await tester.pumpAndSettle();
    expect(find.text('New project'), findsOneWidget);

    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), '/tmp/np'); // location
    await tester.enterText(fields.at(1), 'myapp'); // name
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(newArgs?['positional'], ['myapp']);
    expect((newArgs?['flags'] as Map)['dir'], '/tmp/np');
    expect(announced.single['dir'], '/tmp/np/myapp');
  });

  testWidgets('Create with an empty name surfaces an error and does not dispatch', (tester) async {
    var called = false;
    f.ipc.setConnected(true);
    f.ipc.stub('project.new', (args) async {
      called = true;
      return IpcResponse.ok(id: 'r', data: {'path': '/x', 'name': 'x'});
    });

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(f, const WelcomeView()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New project…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(0), '/tmp/np'); // location only
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.text('Enter a project name.'), findsOneWidget);
  });

  testWidgets('opening a non-repo folder offers Initialize, which dispatches project.init + announces (T-489)', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('clide/window'), (call) async {
      return call.method == 'pickDirectory' ? '/tmp/not-a-repo' : null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('clide/window'), null));
    Map<String, Object?>? initArgs;
    f.ipc.setConnected(true);
    f.ipc.stub('project.init', (args) async {
      initArgs = args;
      return IpcResponse.ok(id: 'r', data: {'path': '/tmp/not-a-repo'});
    });
    final announced = <Map<String, Object?>>[];
    final sub = f.services.messages.subscribe(channel: projectCreatedChannel).listen((m) => announced.add(m.data));
    addTearDown(sub.cancel);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(f, const WelcomeView()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open folder…'));
    await tester.pumpAndSettle();
    expect(find.text('Initialize project'), findsOneWidget);

    await tester.tap(find.text('Initialize project'));
    await tester.pumpAndSettle();
    expect((initArgs?['flags'] as Map)['dir'], '/tmp/not-a-repo');
    expect(announced.single['dir'], '/tmp/not-a-repo');
  });
}
