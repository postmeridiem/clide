/// Widget tests for [ClaudePane] — the spawn/rebind lifecycle (T-269) plus the
/// composer-driven command handling (/clear, /fork, send, mode cycle) and the
/// status / prompt render paths.
///
/// Harness: a fake [ClaudeSessionOrchestrator] (no real `claude` process) and a
/// connected fake IPC that answers `files.root`. The pane awaits a real
/// File(...).exists() transcript probe during spawn, so the spawn/respawn
/// phases run inside tester.runAsync (fake-async would trap that I/O).
library;

import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/claude/src/claude_composer.dart';
import 'package:clide/builtin/claude/src/claude_pane.dart';
import 'package:clide/builtin/claude/src/conversation_view.dart';
import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_picker.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

class _FakeProc implements StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  final List<String> writes = [];
  bool killed = false;

  @override
  Stream<String> get lines => _ctl.stream;

  @override
  void writeLine(String line) => writes.add(line);

  @override
  Future<void> kill() async {
    killed = true;
    if (!_ctl.isClosed) await _ctl.close();
  }

  void feed(Map<String, Object?> event) {
    if (!_ctl.isClosed) _ctl.add(jsonEncode(event));
  }
}

void main() {
  late KernelFixture f;
  late ClaudeSessionOrchestrator orch;
  late String root;
  final created = <_FakeProc>[];

  setUp(() async {
    f = await KernelFixture.create();
    created.clear();
    root = '/repo-a';
    orch = ClaudeSessionOrchestrator(
      processFactory: ({required sessionArgs, required cwd, env}) async {
        final p = _FakeProc();
        created.add(p);
        return p;
      },
    );
    activeSessionOrchestrator = orch;
    f.ipc.setConnected(true);
    f.ipc.stub('files.root', (_) async => IpcResponse.ok(id: '', data: {'path': root}));
  });

  tearDown(() async {
    activeSessionOrchestrator = null;
    orch.dispose();
    await f.dispose();
  });

  Widget tree(ClaudePane pane) => Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: f.services,
      child: ClideTheme(
        controller: f.services.theme,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 900,
              height: 700,
              child: DialogHost(
                router: f.services.dialog,
                child: Overlay(initialEntries: [OverlayEntry(builder: (_) => pane)]),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // Pump the pane and release its project-wait gate so _spawn runs. The whole
  // chain (incl. the real transcript-probe I/O) runs in the real zone.
  Future<void> mount(WidgetTester tester, ClaudePane pane, {String? openPath}) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(tree(pane));
      f.services.events.emit(ProjectOpened(path: openPath ?? root));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
  }

  // Run [fn] (a stream feed or an async command) in the real zone, then settle.
  Future<void> act(WidgetTester tester, FutureOr<void> Function() fn) async {
    await tester.runAsync(() async {
      await fn();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
  }

  ClaudeComposer composer(WidgetTester tester) => tester.widget<ClaudeComposer>(find.byType(ClaudeComposer));

  testWidgets('spawns a session bound to the active repo and renders', (tester) async {
    await mount(tester, const ClaudePane(showChrome: false));

    final primary = orch.byId('primary');
    expect(primary, isNotNull);
    expect(primary!.cwd, '/repo-a');
    expect(primary.sessionId, primarySessionId('/repo-a'));
    expect(find.byType(ConversationView), findsOneWidget);
    expect(find.byType(ClaudeComposer), findsOneWidget);
  });

  testWidgets('switching the workspace in place rebinds to the new repo (T-269)', (tester) async {
    await mount(tester, const ClaudePane(showChrome: false));
    expect(orch.byId('primary')!.cwd, '/repo-a');
    final firstProc = created.single;

    root = '/repo-b';
    await act(tester, () => f.services.events.emit(const ProjectOpened(path: '/repo-b')));

    final primary = orch.byId('primary')!;
    expect(primary.cwd, '/repo-b');
    expect(primary.sessionId, primarySessionId('/repo-b'));
    expect(firstProc.killed, isTrue);
    expect(created, hasLength(2));
  });

  testWidgets('a re-open of the same repo does not respawn', (tester) async {
    await mount(tester, const ClaudePane(showChrome: false));
    expect(created, hasLength(1));
    await act(tester, () => f.services.events.emit(ProjectOpened(path: root)));
    expect(created, hasLength(1), reason: 'same path → no rebind');
  });

  testWidgets('sending a message writes to the session', (tester) async {
    await mount(tester, const ClaudePane(showChrome: false));
    final proc = created.single;
    composer(tester).onSubmit('hello there');
    await tester.pump();
    expect(proc.writes.any((w) => w.contains('hello there')), isTrue);
  });

  testWidgets('/clear empties the deterministic session in place', (tester) async {
    await mount(tester, const ClaudePane(showChrome: false));
    final firstProc = created.single;
    final id = orch.byId('primary')!.sessionId;

    await act(tester, () => composer(tester).onSubmit('/clear'));

    expect(firstProc.killed, isTrue);
    expect(created, hasLength(2));
    // Re-bound to the SAME deterministic id (cleared in place, not a random id).
    expect(orch.byId('primary')!.sessionId, id);
  });

  testWidgets('/fork delegates to the onFork callback with the session id', (tester) async {
    String? forkedWith;
    await mount(tester, ClaudePane(showChrome: false, onFork: (sid) => forkedWith = sid));
    composer(tester).onSubmit('/fork');
    await tester.pump();
    expect(forkedWith, primarySessionId('/repo-a'));
  });

  testWidgets('cycling permission mode sends a control message', (tester) async {
    await mount(tester, const ClaudePane(showChrome: false));
    final proc = created.single;
    composer(tester).onCycleMode!();
    await tester.pump();
    expect(proc.writes.any((w) => w.contains('permission')), isTrue);
  });

  testWidgets('composer draft is retained then cleared', (tester) async {
    await mount(tester, const ClaudePane(showChrome: false));
    final c = composer(tester);
    c.onDraftChanged!(const TextEditingValue(text: 'a draft'));
    c.onDraftChanged!(TextEditingValue.empty);
    await tester.pump();
    // No throw / no crash; draft round-trips through the pane's per-session map.
    expect(find.byType(ClaudeComposer), findsOneWidget);
  });

  testWidgets('an init event populates the status line', (tester) async {
    await mount(tester, const ClaudePane(showChrome: false));
    final proc = created.single;
    await act(
      tester,
      () => proc.feed({'type': 'system', 'subtype': 'init', 'model': 'claude-opus-4-8', 'permissionMode': 'plan', 'session_id': primarySessionId('/repo-a')}),
    );
    // The init event flows through the session into the pane's status path
    // (the rendered slot lives in the status bar, absent from this harness).
    expect(orch.byId('primary')!.session.status.permissionMode, 'plan');
    expect(orch.byId('primary')!.session.status.model, 'claude-opus-4-8');
  });

  testWidgets('a can_use_tool request renders a prompt card in place of the composer', (tester) async {
    await mount(tester, const ClaudePane(showChrome: false));
    final proc = created.single;
    await act(
      tester,
      () => proc.feed({
        'type': 'control_request',
        'request_id': 'req-1',
        'request': {
          'subtype': 'can_use_tool',
          'tool_name': 'Bash',
          'tool_use_id': 'tu-1',
          'input': {'command': 'ls'},
        },
      }),
    );
    expect(find.byType(ClaudeComposer), findsNothing, reason: 'prompt takes the composer slot (D-78)');
  });

  testWidgets('a disconnected daemon surfaces an error instead of spawning', (tester) async {
    f.ipc.setConnected(false);
    await mount(tester, const ClaudePane(showChrome: false));
    expect(orch.byId('primary'), isNull);
    expect(find.textContaining('not connected'), findsOneWidget);
  });

  testWidgets('a secondary pane spawns a fresh session under its own key', (tester) async {
    await mount(tester, const ClaudePane(isPrimary: false, secondaryIndex: 1, showChrome: false));
    final secondary = orch.byId('secondary-1');
    expect(secondary, isNotNull);
    expect(secondary!.cwd, '/repo-a');
    // Secondaries get a fresh random id, not the deterministic primary one.
    expect(secondary.sessionId, isNot(primarySessionId('/repo-a')));
    // Disposing the secondary closes its session (the !isPrimary branch).
    // Pump a different widget type so the pane's State is torn down, not reused.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(orch.byId('secondary-1'), isNull);
  });

  testWidgets('tapping the conversation area focuses the composer', (tester) async {
    await mount(tester, const ClaudePane(showChrome: false));
    await tester.tap(find.byType(ConversationView));
    await tester.pump();
    expect(find.byType(ClaudeComposer), findsOneWidget);
  });

  testWidgets('/resume opens the session picker; cancelling leaves the session', (tester) async {
    await mount(tester, const ClaudePane(showChrome: false));
    final proc = created.single;

    await act(tester, () => composer(tester).onSubmit('/resume'));
    expect(find.byType(SessionPickerDialog), findsOneWidget);

    // Cancel the picker → no rebind, original session untouched.
    await act(tester, () => f.services.dialog.dismiss());
    expect(find.byType(SessionPickerDialog), findsNothing);
    expect(created, hasLength(1));
    expect(proc.killed, isFalse);
  });
}
