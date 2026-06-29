/// Widget tests for the native Claude ConversationView + controller
/// (T-137): renders each transcript item kind as a card, and text
/// selects + copies across cards via ClideSelectionArea (the terminal
/// affordance we keep, T-135).
library;

import 'dart:async';
import 'dart:io';

import 'package:clide/builtin/claude/src/activity_cluster.dart';
import 'package:clide/builtin/claude/src/claude_banner.dart';
import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/conversation_view.dart';
import 'package:clide/builtin/claude/src/image_thumbnail.dart';
import 'package:clide/builtin/claude/src/transcript_publisher.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/builtin/claude/src/workflow_run.dart';
import 'package:clide/clide.dart' show IpcResponse;
import 'package:clide/kernel/kernel.dart' show PaneKeyNav;
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Builder, Focus, Image, FileImage, MediaQuery, Scrollable, ScrollableState, ValueKey;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

final _t = DateTime.utc(2026, 1, 1);

UserMessage _user(String text) => UserMessage(uuid: 'u', timestamp: _t, isSidechain: false, text: text);
AssistantTextMessage _asst(String text) => AssistantTextMessage(uuid: 'a', timestamp: _t, isSidechain: false, text: text);
AssistantThinkingMessage _think(String text) => AssistantThinkingMessage(uuid: 't', timestamp: _t, isSidechain: false, thinking: text);
AssistantToolUse _tool(String name, Map<String, dynamic> input) =>
    AssistantToolUse(uuid: 'tu', timestamp: _t, isSidechain: false, toolUseId: 'x1', name: name, input: input);
ToolResultMessage _result(String content, {bool isError = false}) =>
    ToolResultMessage(uuid: 'r', timestamp: _t, isSidechain: false, toolUseId: 'x1', content: content, isError: isError);
ImageMessage _image(String path, {String? caption, String? label, String? description}) =>
    ImageMessage(uuid: 'i', timestamp: _t, isSidechain: false, path: path, caption: caption, label: label, description: description);

class _MockClipboard {
  Map<String, dynamic> _data = {'text': null};
  Future<Object?> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'Clipboard.setData':
        _data = Map<String, dynamic>.from(call.arguments as Map);
      case 'Clipboard.getData':
        return _data;
      case 'Clipboard.hasStrings':
        final t = _data['text'] as String?;
        return {'value': t != null && t.isNotEmpty};
    }
    return null;
  }

  String? get text => _data['text'] as String?;
}

void main() {
  group('ConversationController', () {
    test('accumulates items from the stream and notifies', () async {
      final ctrl = StreamController<ConversationItem>();
      final c = ConversationController(stream: ctrl.stream);
      addTearDown(c.dispose);
      var notifications = 0;
      c.addListener(() => notifications++);

      expect(c.isEmpty, isTrue);
      ctrl.add(_user('hi'));
      ctrl.add(_asst('hello'));
      // Wait past the coalescing timer (zero-duration, fires after the
      // microtask queue drains).
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(c.items, hasLength(2));
      expect(c.items.first, isA<UserMessage>());
      // Notifications are coalesced: a burst of items collapses to a
      // single notify so the view rebuilds once, not per item.
      expect(notifications, 1);
      await ctrl.close();
    });

    test('onDispose is invoked on dispose', () async {
      final ctrl = StreamController<ConversationItem>();
      var disposed = false;
      final c = ConversationController(stream: ctrl.stream, onDispose: () async => disposed = true);
      c.dispose();
      expect(disposed, isTrue);
      await ctrl.close();
    });

    test('toolUseById indexes AssistantToolUse by toolUseId (T-168)', () async {
      final ctrl = StreamController<ConversationItem>();
      final c = ConversationController(stream: ctrl.stream);
      addTearDown(c.dispose);

      ctrl.add(_tool('Bash', {'command': 'ls'}));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(c.toolUseById['x1'], isNotNull);
      expect(c.toolUseById['x1']!.name, 'Bash');
      await ctrl.close();
    });

    test('partial-uuid items upsert in the controller (T-168)', () async {
      final ctrl = StreamController<ConversationItem>();
      final c = ConversationController(stream: ctrl.stream);
      addTearDown(c.dispose);

      // Two partials with the same `partial-` uuid — second replaces first.
      ctrl.add(AssistantTextMessage(uuid: 'partial-m1', timestamp: _t, isSidechain: false, text: 'hello'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      ctrl.add(AssistantTextMessage(uuid: 'partial-m1', timestamp: _t, isSidechain: false, text: 'hello world'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(c.items.whereType<AssistantTextMessage>(), hasLength(1));
      expect(c.items.whereType<AssistantTextMessage>().first.text, 'hello world');
      await ctrl.close();
    });
  });

  group('ConversationController.fromBus', () {
    test('consumes items published on its publisher/channel', () async {
      final bus = MessageBus();
      addTearDown(bus.dispose);
      final c = ConversationController.fromBus(messages: bus);
      addTearDown(c.dispose);

      bus.publish(ClaudeConversation.publisher, ClaudeConversation.leadChannel, {ClaudeConversation.itemKey: _user('hi')});
      bus.publish(ClaudeConversation.publisher, ClaudeConversation.leadChannel, {ClaudeConversation.itemKey: _asst('hello')});
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(c.items, hasLength(2));
      expect(c.items.first, isA<UserMessage>());
    });

    test('ignores other publishers and channels', () async {
      final bus = MessageBus();
      addTearDown(bus.dispose);
      final c = ConversationController.fromBus(messages: bus);
      addTearDown(c.dispose);

      bus.publish('someone.else', ClaudeConversation.leadChannel, {ClaudeConversation.itemKey: _user('nope')});
      bus.publish(ClaudeConversation.publisher, 'conversation/other', {ClaudeConversation.itemKey: _user('nope')});
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(c.items, isEmpty);
    });
  });

  group('ConversationView', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    Future<ConversationController> pumpWith(
      WidgetTester tester,
      List<ConversationItem> items, {
      Set<String> hiddenToolUseIds = const {},
      Map<String, bool> toolUseOutcomes = const {},
      Set<String> quietErrorToolUseIds = const {},
      Map<String, WorkflowRun> workflows = const {},
      FoldLevel foldLevel = FoldLevel.none,
    }) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final stream = StreamController<ConversationItem>.broadcast();
      final c = ConversationController(stream: stream.stream);
      addTearDown(c.dispose);
      // Disable animations so an in-flight run's ClideSpinner (a perpetual
      // animation) renders static and pumpAndSettle can settle (T-296).
      await tester.pumpWidget(
        harness(
          f,
          Builder(
            builder: (ctx) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
              child: ConversationView(
                controller: c,
                hiddenToolUseIds: hiddenToolUseIds,
                toolUseOutcomes: toolUseOutcomes,
                quietErrorToolUseIds: quietErrorToolUseIds,
                workflows: workflows,
                foldLevel: foldLevel,
              ),
            ),
          ),
        ),
      );
      for (final it in items) {
        stream.add(it);
      }
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('empty controller shows the waiting hint', (tester) async {
      await pumpWith(tester, const []);
      expect(find.text('Waiting for Claude…'), findsOneWidget);
    });

    testWidgets('vim G / gg / j scroll the conversation under vim.normal (T-406)', (tester) async {
      await tester.runAsync(() => f.services.keymap.setPreset('vim'));
      f.services.keymap.setScopeFlag('vim.normal', true);
      addTearDown(() => f.services.keymap.clearScopeFlag('vim.normal'));

      // Enough prose to overflow the 700px viewport so there's room to scroll.
      await pumpWith(tester, [for (var i = 0; i < 40; i++) AssistantTextMessage(uuid: 'a$i', timestamp: _t, isSidechain: false, text: 'line number $i')]);

      // Focus the pane's nav region (its own Focus is PaneKeyNav's outermost).
      final node = tester.widget<Focus>(find.descendant(of: find.byType(PaneKeyNav), matching: find.byType(Focus)).first).focusNode!;
      node.requestFocus();
      await tester.pump();

      final pos = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(pos.maxScrollExtent, greaterThan(0), reason: 'content must overflow to scroll');

      // G → jump to the bottom.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(pos.pixels, pos.maxScrollExtent);

      // gg → jump to the top.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pump();
      expect(pos.pixels, 0);

      // j → down one line (48px); k → back up.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pump();
      expect(pos.pixels, 48);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pump();
      expect(pos.pixels, 0);

      // ctrl+d / ctrl+u → half a viewport down then back up.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pump();
      expect(pos.pixels, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(pos.pixels, 0);

      // h / l / o have no reader-pane semantics — they don't move the scroll.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.pump();
      expect(pos.pixels, 0);
    });

    testWidgets('a Workflow tool-use with a live run renders the workflow card (T-416)', (tester) async {
      var run = const WorkflowRun(toolUseId: 'x1', name: 'parallel-words');
      run = run.foldEvent({
        'subtype': 'task_progress',
        'tool_use_id': 'x1',
        'workflow_progress': [
          {'type': 'workflow_agent', 'index': 1, 'label': 'do alpha', 'model': 'haiku', 'state': 'done'},
          {'type': 'workflow_agent', 'index': 2, 'label': 'do beta', 'model': 'haiku', 'state': 'start'},
        ],
      });
      await pumpWith(
        tester,
        [
          _tool('Workflow', const {'script': 'await parallel([])'}),
        ],
        workflows: {'x1': run},
      );

      // Collapsed: the dedicated workflow collapser with its done/total counter
      // and the workflow name as the summary (no description set → no duplicate).
      expect(find.bySemanticsLabel('workflow, 1/2 agents, collapsed'), findsOneWidget);
      expect(find.text('parallel-words'), findsOneWidget);
      expect(find.text('do alpha'), findsNothing); // folded while collapsed

      // Expand → the per-agent rows show.
      await tester.tap(find.bySemanticsLabel('workflow, 1/2 agents, collapsed'));
      await tester.pumpAndSettle();
      expect(find.text('do alpha'), findsOneWidget);
      expect(find.text('do beta'), findsOneWidget);
    });

    testWidgets('a Workflow tool-use with no run yet falls back to the generic tool card (T-416)', (tester) async {
      await pumpWith(tester, [
        _tool('Workflow', const {'script': 'await parallel([])'}),
      ]);
      // No run snapshot → the generic tool collapser labeled by the tool name.
      expect(find.bySemanticsLabel('Workflow, 1 step, collapsed'), findsOneWidget);
    });

    testWidgets('unfolded conversation cards carry stable per-item identity keys (T-285)', (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final stream = StreamController<ConversationItem>.broadcast();
      final c = ConversationController(stream: stream.stream);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harness(
          f,
          Builder(
            // The in-flight Bash collapser shows a live spinner (T-305); disable
            // animations so it renders static and pumpAndSettle can settle.
            builder: (ctx) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
              child: ConversationView(controller: c, foldLevel: FoldLevel.none),
            ),
          ),
        ),
      );
      stream.add(AssistantToolUse(uuid: 'A', timestamp: _t, isSidechain: false, toolUseId: 'A', name: 'Bash', input: const {'command': 'echo a'}));
      stream.add(AssistantThinkingMessage(uuid: 'B', timestamp: _t, isSidechain: false, thinking: 'thinking body'));
      await tester.pumpAndSettle();
      // Each top-level card is keyed by its item uuid so a streaming reshape
      // pins card State (collapse/hover) to its logical item, not its position.
      expect(find.byKey(const ValueKey('turn.A')), findsOneWidget);
      expect(find.byKey(const ValueKey('turn.B')), findsOneWidget);
    });

    testWidgets('a driven-in drawing card renders the SVG + caption (T-318)', (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final stream = StreamController<ConversationItem>.broadcast();
      final c = ConversationController(stream: stream.stream);
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(f, ConversationView(controller: c, foldLevel: FoldLevel.none)));
      stream.add(
        DrawingMessage(
          uuid: 'D',
          timestamp: _t,
          isSidechain: false,
          svg: '<svg viewBox="0 0 20 10"><rect width="20" height="10" fill="#FF0000"/></svg>',
          label: 'Build pipeline',
          description: 'how it connects',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('turn.D')), findsOneWidget);
      expect(find.text('Build pipeline'), findsOneWidget);
      expect(find.text('how it connects'), findsOneWidget);
    });

    testWidgets('a folded activity cluster carries a stable identity key (T-285)', (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final stream = StreamController<ConversationItem>.broadcast();
      final c = ConversationController(stream: stream.stream);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harness(
          f,
          Builder(
            builder: (ctx) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
              child: ConversationView(controller: c, foldLevel: FoldLevel.tools),
            ),
          ),
        ),
      );
      stream.add(AssistantToolUse(uuid: 'A', timestamp: _t, isSidechain: false, toolUseId: 'A', name: 'Bash', input: const {'command': 'echo a'}));
      stream.add(AssistantToolUse(uuid: 'B', timestamp: _t, isSidechain: false, toolUseId: 'B', name: 'Read', input: const {'file_path': '/a'}));
      await tester.pumpAndSettle();
      // The cluster is keyed by its first item's uuid, so re-folding never
      // reattaches the holder's expand State to the wrong cluster by position.
      expect(find.byKey(const ValueKey('cluster.A')), findsOneWidget);
    });

    testWidgets('clicking a bare T-ref in a message opens the tickets reader (T-279)', (tester) async {
      Message? opened;
      final sub = f.services.messages.subscribe(publisher: 'builtin.tickets', channel: 'selection').listen((m) => opened = m);
      addTearDown(sub.cancel);
      await pumpWith(tester, [_user('please look at T-281')]);
      await tester.tap(find.text('T-281'));
      await tester.pumpAndSettle();
      expect(opened, isNotNull);
      expect(opened!.data['id'], 'T-281');
    });

    testWidgets('clicking a bare D-ref opens the decisions reader (T-279)', (tester) async {
      Message? opened;
      final sub = f.services.messages.subscribe(publisher: 'builtin.decisions', channel: 'selection').listen((m) => opened = m);
      addTearDown(sub.cancel);
      await pumpWith(tester, [_asst('we resume cleanly per D-77 today')]);
      await tester.tap(find.text('D-77'));
      await tester.pumpAndSettle();
      expect(opened, isNotNull);
      expect(opened!.data['id'], 'D-77');
    });

    testWidgets('a pasted-image @path token renders an inline thumbnail (T-236/T-254)', (tester) async {
      await pumpWith(tester, [_user('look at this @/tmp/clide/paste-1.png please')]);
      expect(find.byType(ImageThumbnail), findsOneWidget);
      // The prose around the token still renders.
      expect(find.textContaining('look at this'), findsWidgets);
    });

    testWidgets('multiple image tokens each render a thumbnail (T-236)', (tester) async {
      await pumpWith(tester, [_user('@/tmp/a.png and @/tmp/b.jpg')]);
      expect(find.byType(ImageThumbnail), findsNWidgets(2));
    });

    testWidgets('a non-image @path stays literal text (T-236)', (tester) async {
      await pumpWith(tester, [_user('see @/tmp/notes.txt for details')]);
      expect(find.byType(ImageThumbnail), findsNothing);
    });

    testWidgets('consecutive same-file edits collapse into one "# edits" card (T-296)', (tester) async {
      AssistantToolUse edit(String id, String path) =>
          AssistantToolUse(uuid: id, timestamp: _t, isSidechain: false, toolUseId: id, name: 'Edit', input: {'file_path': path});
      ToolResultMessage ok(String id) => ToolResultMessage(uuid: 'r$id', timestamp: _t, isSidechain: false, toolUseId: id, content: 'done', isError: false);
      await pumpWith(tester, [edit('e1', '/lib/x.dart'), ok('e1'), edit('e2', '/lib/x.dart'), ok('e2')], foldLevel: FoldLevel.tools);
      // One bundled card labelled "2 edits" with an aggregate status indicator.
      expect(find.text('2 edits'), findsOneWidget);
      expect(find.byType(ClideStatusIndicator), findsOneWidget);
    });

    testWidgets('an edit to a different file is not bundled with the first (T-296)', (tester) async {
      AssistantToolUse edit(String id, String path) =>
          AssistantToolUse(uuid: id, timestamp: _t, isSidechain: false, toolUseId: id, name: 'Edit', input: {'file_path': path});
      await pumpWith(tester, [edit('e1', '/a.dart'), edit('e2', '/b.dart')], foldLevel: FoldLevel.tools);
      // Two lone edits, different files → no "edits" bundle.
      expect(find.textContaining('edits'), findsNothing);
    });

    testWidgets('meta items fold into a collapsed activity card; tap expands (T-230)', (tester) async {
      await pumpWith(tester, [
        _tool('Bash', const {'command': 'echo hi'}),
        // A second, distinct in-flight tool call (T-262 folds a success
        // result into its call card, so two *calls* are what make 2 steps).
        AssistantToolUse(uuid: 'tu2', timestamp: _t, isSidechain: false, toolUseId: 'x2', name: 'Read', input: const {'file_path': '/a'}),
      ], foldLevel: FoldLevel.tools);
      // Collapsed by default: one card with a step count, not the raw rows.
      expect(find.text('2 steps'), findsOneWidget);
      expect(find.bySemanticsLabel('Activity, 2 steps, collapsed'), findsOneWidget);
      // Activating it expands to reveal the folded steps.
      await tester.tap(find.bySemanticsLabel('Activity, 2 steps, collapsed'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Activity, 2 steps, expanded'), findsOneWidget);
    });

    testWidgets('a folded success result is not a separate step — merged into its call (T-262 note D)', (tester) async {
      await pumpWith(tester, [
        _tool('Bash', const {'command': 'echo hi'}),
        _result('hi there'),
      ], foldLevel: FoldLevel.tools);
      // The call + its success result is ONE unit now: 1 step, not 2.
      expect(find.text('1 step'), findsOneWidget);
      expect(find.text('2 steps'), findsNothing);
      // The result is not double-rendered: no standalone result card.
      expect(find.text('Bash · result'), findsNothing);
    });

    testWidgets('an image card renders with the "image" label, the file, and its caption (T-249)', (tester) async {
      await pumpWith(tester, [_image('/no/such/file.png', caption: 'before the fix')]);
      expect(find.text('image'), findsOneWidget);
      expect(find.text('before the fix'), findsOneWidget);
      // The image is wired to the resolved file path (display-only, D-78).
      final img = tester.widget<Image>(find.byType(Image));
      expect((img.image as FileImage).file.path, '/no/such/file.png');
    });

    testWidgets('an image card renders its --file label and description (T-316)', (tester) async {
      await pumpWith(tester, [_image('/no/such/shot.png', label: 'HUD v3', description: 'note the cramped status row', caption: 'before')]);
      expect(find.text('HUD v3'), findsOneWidget);
      expect(find.text('note the cramped status row'), findsOneWidget);
      expect(find.text('before'), findsOneWidget);
    });

    testWidgets('inject() drives a new image card into a live view (T-249)', (tester) async {
      final c = await pumpWith(tester, [_user('hi')]);
      expect(find.text('image'), findsNothing);
      c.inject(_image('/no/such/shot.png'));
      await tester.pumpAndSettle();
      expect(find.text('image'), findsOneWidget);
    });

    testWidgets('a failed result surfaces first-class, not folded (T-230)', (tester) async {
      await pumpWith(tester, [
        _tool('Bash', const {'command': 'boom'}),
        _result('error output', isError: true),
      ], foldLevel: FoldLevel.tools);
      // The tool call folds (1 step); the error result is sticky → no 2-step card.
      expect(find.text('1 step'), findsOneWidget);
      expect(find.textContaining('error output'), findsWidgets);
    });

    testWidgets('empty controller shows the provided emptyState instead', (tester) async {
      final stream = StreamController<ConversationItem>.broadcast();
      final c = ConversationController(stream: stream.stream);
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(f, ConversationView(controller: c, emptyState: const ClideText('CUSTOM EMPTY'))));
      expect(find.text('CUSTOM EMPTY'), findsOneWidget);
      expect(find.text('Waiting for Claude…'), findsNothing);
    });

    testWidgets('renders a card per item kind with role/tool labels', (tester) async {
      await pumpWith(tester, [
        _user('a question'),
        _asst('an answer'),
        _think('hmm'),
        _tool('Bash', {'command': 'ls'}),
        _result('ok'),
        _result('boom', isError: true),
      ]);
      expect(find.text('you'), findsOneWidget);
      expect(find.text('claude'), findsOneWidget);
      expect(find.text('thinking'), findsOneWidget);
      expect(find.text('Bash'), findsOneWidget);
      // T-262: a successful result folds into the tool card (no standalone
      // "Bash · result"); a failed result keeps its prominent standalone card.
      expect(find.text('Bash · result'), findsNothing);
      expect(find.text('Bash · error'), findsOneWidget);
    });

    testWidgets('AskUserQuestion tool-use and its result are hidden (it shows as a prompt)', (tester) async {
      await pumpWith(tester, [
        _asst('let me ask'),
        AssistantToolUse(uuid: 'au', timestamp: _t, isSidechain: false, toolUseId: 'auq1', name: 'AskUserQuestion', input: const {'questions': []}),
        ToolResultMessage(uuid: 'ar', timestamp: _t, isSidechain: false, toolUseId: 'auq1', content: 'answered', isError: false),
        _asst('thanks'),
      ]);
      expect(find.text('AskUserQuestion'), findsNothing);
      expect(find.text('let me ask'), findsOneWidget);
      expect(find.text('thanks'), findsOneWidget);
    });

    testWidgets('a sidechain prompt folds into its Agent card; never labelled "you" (T-263)', (tester) async {
      await pumpWith(tester, [
        AssistantToolUse(
          uuid: 'agt-msg',
          timestamp: _t,
          isSidechain: false,
          toolUseId: 'task1',
          name: 'Task',
          input: const {'description': 'explore the codebase'},
        ),
        UserMessage(uuid: 'p1', timestamp: _t, isSidechain: true, text: 'find all the widgets'),
      ]);
      // Never the blue "you", and no standalone block (folded → suppressed).
      expect(find.text('you'), findsNothing);
      expect(find.text('agent prompt'), findsNothing); // not a standalone card here
      expect(find.text('Task'), findsOneWidget);
      // Collapsed by default: the prompt is hidden.
      expect(find.text('find all the widgets'), findsNothing);

      // Expand the Agent collapser → a "prompt" segment reveals the folded prompt.
      await tester.tap(find.bySemanticsLabel('Task, 1 step, collapsed'));
      await tester.pumpAndSettle();
      expect(find.text('prompt'), findsOneWidget); // segment sub-label
      expect(find.text('find all the widgets'), findsOneWidget);
    });

    testWidgets('a stream-json prompt folds via parentToolUseId, not "you" (T-338)', (tester) async {
      // The live stream-json wire flags sub-agent prompts with parent_tool_use_id
      // (the Task tool-use id) and NO isSidechain/parentUuid — the prompt must
      // still fold into the Agent card rather than render as a blue "you" turn.
      await pumpWith(tester, [
        AssistantToolUse(uuid: 'agt-msg', timestamp: _t, isSidechain: false, toolUseId: 'task1', name: 'Task', input: const {'description': 'explore'}),
        UserMessage(uuid: 'sp', timestamp: _t, isSidechain: true, parentToolUseId: 'task1', text: 'find all the widgets'),
      ]);
      expect(find.text('you'), findsNothing);
      expect(find.text('agent prompt'), findsNothing);
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('find all the widgets'), findsNothing); // folded, collapsed

      await tester.tap(find.bySemanticsLabel('Task, 1 step, collapsed'));
      await tester.pumpAndSettle();
      expect(find.text('find all the widgets'), findsOneWidget);
    });

    testWidgets('an orphan sidechain prompt renders as muted "agent prompt", never "you" (T-263)', (tester) async {
      // No Agent tool-use to attach to → stays standalone, but relabelled.
      await pumpWith(tester, [UserMessage(uuid: 'orphan', timestamp: _t, isSidechain: true, text: 'orphaned agent instructions')]);
      expect(find.text('you'), findsNothing);
      expect(find.text('agent prompt'), findsOneWidget);
    });

    testWidgets('parallel agents: each prompt attaches to its own card via parentUuid (T-263)', (tester) async {
      // Document order scrambles the prompts so a nearest-preceding heuristic
      // would misattach BOTH to agent B; parentUuid must route them correctly.
      await pumpWith(tester, [
        AssistantToolUse(uuid: 'mA', timestamp: _t, isSidechain: false, toolUseId: 'tA', name: 'Task', input: const {'description': 'agent A'}),
        AssistantToolUse(uuid: 'mB', timestamp: _t, isSidechain: false, toolUseId: 'tB', name: 'Task', input: const {'description': 'agent B'}),
        UserMessage(uuid: 'pB', timestamp: _t, isSidechain: true, parentUuid: 'mB', text: 'PROMPT FOR B'),
        UserMessage(uuid: 'pA', timestamp: _t, isSidechain: true, parentUuid: 'mA', text: 'PROMPT FOR A'),
      ]);
      // Two collapsed Agent collapsers; the first belongs to card A.
      expect(find.text('you'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Task, 1 step, collapsed').first);
      await tester.pumpAndSettle();
      // Only card A is expanded → its prompt (A) shows; B's stays folded away.
      // Nearest-preceding would have put A's prompt under B, revealing nothing.
      expect(find.text('PROMPT FOR A'), findsOneWidget);
      expect(find.text('PROMPT FOR B'), findsNothing);
    });

    testWidgets('the sub-agent run nests in a holder under its Agent card (T-264)', (tester) async {
      await pumpWith(tester, [
        AssistantToolUse(uuid: 'mA', timestamp: _t, isSidechain: false, toolUseId: 'tA', name: 'Task', input: const {'description': 'explore'}),
        UserMessage(uuid: 'p', timestamp: _t, isSidechain: true, parentUuid: 'mA', text: 'go explore'),
        // A sidechain tool call — part of the run, chained off the prompt.
        AssistantToolUse(
          uuid: 's1',
          timestamp: _t,
          isSidechain: true,
          parentUuid: 'p',
          toolUseId: 'sb',
          name: 'Bash',
          input: const {'command': 'grep widgets'},
        ),
      ]);
      expect(find.text('Task'), findsOneWidget);
      // The run is a nested holder titled "agent run", collapsed by default —
      // the run's Bash card is not loose in the main chain.
      expect(find.bySemanticsLabel('agent run, 1 step, collapsed'), findsOneWidget);
      expect(find.text('Bash'), findsNothing); // run card hidden while holder collapsed

      await tester.tap(find.bySemanticsLabel('agent run, 1 step, collapsed'));
      await tester.pumpAndSettle();
      expect(find.text('Bash'), findsOneWidget); // the run's tool card, now nested + visible
    });

    testWidgets('the returned result is not duplicated when the run is shown (T-264 note E)', (tester) async {
      await pumpWith(tester, [
        AssistantToolUse(uuid: 'mA', timestamp: _t, isSidechain: false, toolUseId: 'tA', name: 'Task', input: const {'description': 'x'}),
        UserMessage(uuid: 'p', timestamp: _t, isSidechain: true, parentUuid: 'mA', text: 'go'),
        AssistantTextMessage(uuid: 's1', timestamp: _t, isSidechain: true, parentUuid: 'p', text: 'THE FINAL ANSWER'),
        // The Task's returned result (main chain) — equals the run's final prose.
        ToolResultMessage(uuid: 'tr', timestamp: _t, isSidechain: false, parentUuid: 'mA', toolUseId: 'tA', content: 'THE FINAL ANSWER', isError: false),
      ]);
      // Expand the Agent collapser (its "result" segment would show here if kept)…
      await tester.tap(find.bySemanticsLabel('Task, 1 step, collapsed'));
      await tester.pumpAndSettle();
      // …and the nested run.
      await tester.tap(find.bySemanticsLabel('agent run, 1 step, collapsed'));
      await tester.pumpAndSettle();
      // The answer appears once (in the run), not also as a folded result segment.
      expect(find.textContaining('THE FINAL ANSWER'), findsOneWidget);
      expect(find.text('result'), findsNothing); // no result sub-label on the Agent card
    });

    testWidgets('parallel agents: each run nests under its own card via parentUuid (T-264)', (tester) async {
      await pumpWith(tester, [
        AssistantToolUse(uuid: 'mA', timestamp: _t, isSidechain: false, toolUseId: 'tA', name: 'Task', input: const {'description': 'A'}),
        AssistantToolUse(uuid: 'mB', timestamp: _t, isSidechain: false, toolUseId: 'tB', name: 'Task', input: const {'description': 'B'}),
        AssistantToolUse(uuid: 'sA', timestamp: _t, isSidechain: true, parentUuid: 'mA', toolUseId: 'sbA', name: 'Bash', input: const {'command': 'CMD_A'}),
        AssistantToolUse(uuid: 'sB', timestamp: _t, isSidechain: true, parentUuid: 'mB', toolUseId: 'sbB', name: 'Bash', input: const {'command': 'CMD_B'}),
      ]);
      // Correct routing → two separate 1-step runs. A nearest-preceding heuristic
      // would pool both under agent B as one 2-step run.
      expect(find.bySemanticsLabel('agent run, 1 step, collapsed'), findsNWidgets(2));
      expect(find.bySemanticsLabel('agent run, 2 steps, collapsed'), findsNothing);
    });

    testWidgets('parallel agents: interleaved run items route by parentToolUseId to their own card (T-342)', (tester) async {
      await pumpWith(tester, [
        AssistantToolUse(uuid: 'mA', timestamp: _t, isSidechain: false, toolUseId: 'tA', name: 'Task', input: const {'description': 'A'}),
        AssistantToolUse(uuid: 'mB', timestamp: _t, isSidechain: false, toolUseId: 'tB', name: 'Task', input: const {'description': 'B'}),
        // Sidechain prose for the two agents, interleaved + tagged with the
        // owning agent's tool-use id (T-338 direct route).
        AssistantTextMessage(uuid: 'rB', timestamp: _t, isSidechain: true, parentToolUseId: 'tB', text: 'FROM B'),
        AssistantTextMessage(uuid: 'rA', timestamp: _t, isSidechain: true, parentToolUseId: 'tA', text: 'FROM A'),
      ]);
      // Each agent gets its own 1-step run, not one pooled 2-step run under the
      // last-emitted agent — proof the interleaved items routed by their own
      // parentToolUseId (pooling would show one "2 steps" run, zero "1 step").
      expect(find.bySemanticsLabel('agent run, 1 step, collapsed'), findsNWidgets(2));
      expect(find.bySemanticsLabel('agent run, 2 steps, collapsed'), findsNothing);
    });

    testWidgets('parallel agents: an unattributable sidechain item orphans, not swept into the last agent (T-342)', (tester) async {
      await pumpWith(tester, [
        AssistantToolUse(uuid: 'mA', timestamp: _t, isSidechain: false, toolUseId: 'tA', name: 'Task', input: const {'description': 'A'}),
        AssistantToolUse(uuid: 'mB', timestamp: _t, isSidechain: false, toolUseId: 'tB', name: 'Task', input: const {'description': 'B'}),
        // No parentToolUseId and no rooted parentUuid chain — unattributable.
        AssistantTextMessage(uuid: 'lost', timestamp: _t, isSidechain: true, text: 'UNROUTED PROSE'),
      ]);
      // With >1 agent the nearest-agent fallback is dropped, so this orphans and
      // renders inline as "agent" prose instead of being filed under agent B.
      expect(find.text('UNROUTED PROSE'), findsOneWidget); // visible inline, not hidden in a collapsed run
      expect(find.text('agent'), findsOneWidget);
      expect(find.bySemanticsLabel('agent run, 1 step, collapsed'), findsNothing); // neither agent gained a run from it
    });

    testWidgets('a successful sidechain result folds into its run tool card, not a separate step (T-264)', (tester) async {
      await pumpWith(tester, [
        AssistantToolUse(uuid: 'mA', timestamp: _t, isSidechain: false, toolUseId: 'tA', name: 'Task', input: const {'description': 'x'}),
        UserMessage(uuid: 'p', timestamp: _t, isSidechain: true, parentUuid: 'mA', text: 'go'),
        AssistantToolUse(uuid: 's1', timestamp: _t, isSidechain: true, parentUuid: 'p', toolUseId: 'sb', name: 'Bash', input: const {'command': 'ls'}),
        ToolResultMessage(uuid: 'sr', timestamp: _t, isSidechain: true, parentUuid: 's1', toolUseId: 'sb', content: 'file listing', isError: false),
      ]);
      // The tool call + its success result is ONE step in the run, not two.
      expect(find.bySemanticsLabel('agent run, 1 step, collapsed'), findsOneWidget);
      expect(find.bySemanticsLabel('agent run, 2 steps, collapsed'), findsNothing);
    });

    testWidgets('sidechain assistant prose is attributed to "agent", not "claude" (T-265)', (tester) async {
      // An orphan sidechain prose (no resolvable Agent) renders inline, still
      // attributed to the agent — never the main-thread coral "claude".
      await pumpWith(tester, [AssistantTextMessage(uuid: 's', timestamp: _t, isSidechain: true, text: 'sub-agent says hi')]);
      expect(find.text('agent'), findsOneWidget);
      expect(find.text('claude'), findsNothing);
    });

    testWidgets('sidechain thinking is attributed to "agent thinking" (T-265)', (tester) async {
      await pumpWith(tester, [AssistantThinkingMessage(uuid: 's', timestamp: _t, isSidechain: true, thinking: 'hmm let me think')]);
      expect(find.text('agent thinking'), findsOneWidget);
      expect(find.text('thinking'), findsNothing);
    });

    testWidgets('main-thread prose + thinking keep "claude"/"thinking" (T-265 unchanged)', (tester) async {
      await pumpWith(tester, [_asst('main says hi'), _think('main thought')]);
      expect(find.text('claude'), findsOneWidget);
      expect(find.text('thinking'), findsOneWidget);
      expect(find.text('agent'), findsNothing);
      expect(find.text('agent thinking'), findsNothing);
    });

    testWidgets('a permission-prompted tool-use is hidden but its result is kept', (tester) async {
      await pumpWith(
        tester,
        [
          _tool('Write', {'file_path': '/tmp/x'}),
          _result('done'),
        ],
        hiddenToolUseIds: {'x1'}, // _tool + _result both use toolUseId 'x1'
      );
      expect(find.text('Write'), findsNothing); // payload hidden
      expect(find.text('done'), findsOneWidget); // result kept
      // Label now includes paired tool name (T-168).
      expect(find.text('Write · result'), findsOneWidget);
    });

    testWidgets('a resolved permission tool-use is shown collapsed, not hidden', (tester) async {
      await pumpWith(
        tester,
        [
          _tool('Write', {'file_path': '/tmp/x'}),
          _result('done'),
        ],
        hiddenToolUseIds: {'x1'},
        toolUseOutcomes: {'x1': true}, // approved
      );
      final handle = tester.ensureSemantics();
      expect(find.text('Write'), findsOneWidget); // shown (resolved) — collapser label
      // T-305: the resolved tool is its own collapser, collapsed by default.
      expect(find.bySemanticsLabel('Write, 1 step, collapsed'), findsOneWidget);
      // T-262: the resolved card folds its result + carries a success check on
      // the collapser (the inner card is hidden while collapsed).
      expect(find.byWidgetPredicate((w) => w is ClideStatusIndicator && w.status == ClideRunStatus.success), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an injected user message renders as a muted "context" card, not "you"', (tester) async {
      await pumpWith(tester, [
        UserMessage(uuid: 'i', timestamp: _t, isSidechain: false, text: 'Base directory for this skill: /x\n\n# pql', injected: true),
        _user('a real question'),
      ]);
      expect(find.text('context'), findsOneWidget);
      expect(find.text('you'), findsOneWidget); // the real one
    });

    testWidgets('tool-use body: Bash shows the command in the collapsed summary (T-168)', (tester) async {
      await pumpWith(tester, [
        _tool('Bash', {'command': 'ls -la'}),
      ]);
      // Collapser starts collapsed — the command appears as the echoed summary.
      expect(find.text('ls -la'), findsOneWidget);
      // Expand the collapser to verify the inner body is a bash code block.
      await tester.tap(find.bySemanticsLabel('Bash, 1 step, collapsed'));
      await tester.pump();
      final blocks = tester.widgetList<ClideCodeBlock>(find.byType(ClideCodeBlock)).toList();
      expect(blocks.any((b) => b.language == 'bash' && b.source.contains('ls -la')), isTrue);
    });

    testWidgets('tool-use body: Read/Grep/LS shows a compact path label (T-168)', (tester) async {
      await pumpWith(tester, [
        _tool('Read', {'file_path': '/foo/bar.dart'}),
      ]);
      // The path label appears (collapsed summary or body).
      expect(find.text('/foo/bar.dart'), findsOneWidget);
    });

    testWidgets('a successful result folds into the tool-use card with a check (T-262)', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWith(tester, [
        _tool('Read', {'file_path': '/foo/bar.dart'}),
        _result('final answer = 42;'),
      ]);
      // No standalone success result card — it's folded into the Read card.
      expect(find.text('Read · result'), findsNothing);
      // The collapser shows a success check while collapsed.
      expect(find.byWidgetPredicate((w) => w is ClideStatusIndicator && w.status == ClideRunStatus.success), findsOneWidget);
      // Collapsed by default: neither the call body nor the result is shown yet.
      expect(find.text('final answer = 42;'), findsNothing);

      // Expand: the call segment, a "result" sub-label, and the folded result
      // as a colorized code block (Read → grammar from the .dart path).
      await tester.tap(find.bySemanticsLabel('Read, 1 step, collapsed'));
      await tester.pumpAndSettle();
      expect(find.text('result'), findsOneWidget); // segment sub-label
      final blocks = tester.widgetList<ClideCodeBlock>(find.byType(ClideCodeBlock)).toList();
      expect(blocks.any((b) => b.language == 'dart' && b.source == 'final answer = 42;'), isTrue);
      handle.dispose();
    });

    testWidgets('Bash result folds as a bash code block; in-flight call has no check (T-262)', (tester) async {
      final handle = tester.ensureSemantics();
      // In-flight: a call with no result yet → no check, no folded result.
      await pumpWith(tester, [
        _tool('Bash', {'command': 'ls'}),
      ]);
      expect(find.bySemanticsLabel('succeeded'), findsNothing);
      expect(find.bySemanticsLabel('failed'), findsNothing);
      handle.dispose();
    });

    testWidgets('Bash success result infers the bash language for the folded block (T-262)', (tester) async {
      await pumpWith(tester, [
        _tool('Bash', {'command': 'echo hi'}),
        _result('hi\nthere'),
      ]);
      await tester.tap(find.bySemanticsLabel('Bash, 1 step, collapsed'));
      await tester.pumpAndSettle();
      final blocks = tester.widgetList<ClideCodeBlock>(find.byType(ClideCodeBlock)).toList();
      expect(blocks.any((b) => b.language == 'bash' && b.source == 'hi\nthere'), isTrue);
    });

    testWidgets('a failed result is NOT folded: standalone error card + red header mark (T-262)', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWith(tester, [
        _tool('Bash', {'command': 'boom'}),
        _result('permission denied', isError: true),
      ]);
      // The error stays a separate prominent card…
      expect(find.text('Bash · error'), findsOneWidget);
      expect(find.text('permission denied'), findsOneWidget);
      // …and the call collapser carries a red failure mark for symmetry (note C).
      expect(find.byWidgetPredicate((w) => w is ClideStatusIndicator && w.status == ClideRunStatus.error), findsOneWidget);
      handle.dispose();
    });

    testWidgets('error result label includes paired tool name (T-168)', (tester) async {
      await pumpWith(tester, [
        _tool('Bash', {'command': 'cat nonexistent'}),
        _result('No such file', isError: true),
      ]);
      expect(find.text('Bash · error'), findsOneWidget);
    });

    testWidgets('a quiet (user-initiated) denial folds to a muted "denied" card (T-340)', (tester) async {
      await pumpWith(
        tester,
        [
          _tool('Bash', {'command': 'rm -rf x'}),
          _result('Denied — too complex\nretry simpler', isError: true),
        ],
        quietErrorToolUseIds: {'x1'}, // the toolUseId shared by _tool/_result
      );
      // Labelled "denied", not the loud "error", and folded by default so the
      // body (its second line) is hidden behind a collapsed summary.
      expect(find.text('Bash · denied'), findsOneWidget);
      expect(find.text('Bash · error'), findsNothing);
      expect(find.textContaining('retry simpler'), findsNothing);
    });

    testWidgets('a genuine error (not in the quiet set) stays expanded red (T-340)', (tester) async {
      await pumpWith(tester, [
        _tool('Bash', {'command': 'rm -rf x'}),
        _result('Denied — too complex\nretry simpler', isError: true),
      ]);
      // Same content, but not flagged quiet → the normal expanded error path.
      expect(find.text('Bash · error'), findsOneWidget);
      expect(find.text('Bash · denied'), findsNothing);
      expect(find.textContaining('retry simpler'), findsOneWidget);
    });

    testWidgets('result without a paired tool_use uses plain "result" label (T-168)', (tester) async {
      // Orphan result (no matching tool_use in the controller).
      await pumpWith(tester, [ToolResultMessage(uuid: 'r-orphan', timestamp: _t, isSidechain: false, toolUseId: 'unknown-id', content: 'ok', isError: false)]);
      expect(find.text('result'), findsOneWidget);
    });

    testWidgets('error result defaults expanded so it is visible (T-168)', (tester) async {
      // An error result should show its content without requiring an expand tap.
      await pumpWith(tester, [
        _tool('Bash', {'command': 'bad'}),
        _result('permission denied', isError: true),
      ]);
      // Error content visible without expand.
      expect(find.text('permission denied'), findsOneWidget);
    });

    testWidgets('a one-line tool result renders inline (no collapse caret)', (tester) async {
      await pumpWith(tester, [_result('hello-from-spike')]);
      expect(find.text('hello-from-spike'), findsOneWidget);
      expect(find.byType(ClideIcon), findsNothing); // not collapsible → no caret
    });

    testWidgets('a multi-line tool result starts collapsed with a first-line summary', (tester) async {
      await pumpWith(tester, [_result('first line\nsecond line\nthird line')]);
      // Collapsed: caret present, summary (first line) shown, full body hidden.
      expect(find.byType(ClideIcon), findsOneWidget);
      expect(find.text('first line'), findsOneWidget);
      expect(find.text('first line\nsecond line\nthird line'), findsNothing);

      await tester.tap(find.byType(ClideIcon));
      await tester.pump();
      expect(find.text('first line\nsecond line\nthird line'), findsOneWidget);
    });

    testWidgets('select-all + copy spans multiple cards', (tester) async {
      final clipboard = _MockClipboard();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, clipboard.handleMethodCall);
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await pumpWith(tester, [_user('question text'), _asst('answer text')]);

      // Focus the selection region, select all, copy.
      final region = find.byType(ClideSelectionArea);
      expect(region, findsOneWidget);
      await tester.tap(region);
      await tester.pump();
      Future<void> keys(LogicalKeyboardKey k) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(k);
        await tester.sendKeyUpEvent(k);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();
      }

      await keys(LogicalKeyboardKey.keyA);
      await keys(LogicalKeyboardKey.keyC);
      await tester.pump();

      final copied = clipboard.text ?? '';
      expect(copied, contains('question text'));
      expect(copied, contains('answer text'));
    });

    testWidgets('a tail Bash card shows a live-tail segment; no workspace source → muted note (T-325)', (tester) async {
      await pumpWith(tester, [
        AssistantToolUse(uuid: 'b1', timestamp: _t, isSidechain: false, toolUseId: 'tb', name: 'Bash', input: const {'command': 'tail -f app.log'}),
      ]);
      // Collapsed by default — the segment only builds (and connects) on expand.
      expect(find.text('live tail'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Bash, 1 step, collapsed'));
      await tester.pumpAndSettle();
      expect(find.text('live tail'), findsOneWidget); // segment surfaced for a tail command
      // No project open in the fixture → no resolvable source → the muted note,
      // never a broken/empty terminal.
      expect(find.text('no independent source to follow'), findsOneWidget);
    });

    testWidgets('synthetic CLI-local output renders as a muted "clide" card, not claude prose (T-411)', (tester) async {
      await pumpWith(tester, [
        AssistantTextMessage(uuid: 's1', timestamp: _t, isSidechain: false, text: "/effort isn't available in this environment.", synthetic: true),
      ]);
      expect(find.text('clide'), findsOneWidget);
      expect(find.text('claude'), findsNothing);
      expect(find.textContaining("isn't available"), findsOneWidget);
    });

    testWidgets('an ordinary Bash card has no live-tail segment (T-325)', (tester) async {
      await pumpWith(tester, [
        AssistantToolUse(uuid: 'b2', timestamp: _t, isSidechain: false, toolUseId: 'tb2', name: 'Bash', input: const {'command': 'ls -la'}),
      ]);
      await tester.tap(find.bySemanticsLabel('Bash, 1 step, collapsed'));
      await tester.pumpAndSettle();
      expect(find.text('live tail'), findsNothing); // no tail intent → no segment
    });
  });

  // The file-ref open + live-tail handlers read project.current, so these need a
  // real workspace open. project.open() spawns `git rev-parse` whose exit
  // ReceivePort is trapped under the fake-async testWidgets zone (T-280) — so the
  // open is done in setUp (real async), never inside a testWidgets body.
  group('ConversationView with an open workspace', () {
    late KernelFixture f;
    late Directory proj;

    setUp(() async {
      f = await KernelFixture.create();
      proj = await Directory.systemTemp.createTemp('clide_ws_');
      await Directory('${proj.path}/.git').create();
      await File('${proj.path}/lib/app.dart').create(recursive: true);
      await File('${proj.path}/app.log').writeAsString('starting up\n');
      await f.services.project.open(proj.path);
    });
    tearDown(() async {
      await f.dispose();
      if (await proj.exists()) await proj.delete(recursive: true);
    });

    Future<ConversationController> pumpWith(WidgetTester tester, List<ConversationItem> items) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final stream = StreamController<ConversationItem>.broadcast();
      final c = ConversationController(stream: stream.stream);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harness(
          f,
          Builder(
            builder: (ctx) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
              child: ConversationView(controller: c, foldLevel: FoldLevel.none),
            ),
          ),
        ),
      );
      for (final it in items) {
        stream.add(it);
      }
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('clicking a repo file ref opens it in the editor (T-300)', (tester) async {
      // Capture the editor.open IPC the file-ref tap fires.
      String? openedPath;
      int? openedLine;
      f.ipc.stub('editor.open', (args) async {
        openedPath = args['path'] as String?;
        openedLine = args['line'] as int?;
        return IpcResponse.ok(id: '1', data: {'path': args['path']});
      });

      await pumpWith(tester, [_user('crash at lib/app.dart:42 today')]);
      await tester.tap(find.text('lib/app.dart:42'));
      await tester.pumpAndSettle();

      // _resolveRepoFile resolved the ref against project.current, _openFile sent
      // the absolute path + line to editor.open.
      expect(openedPath, '${proj.path}/lib/app.dart');
      expect(openedLine, 42);
    });

    testWidgets('a tail Bash card follows a real workspace file (T-325)', (tester) async {
      // The tail command names a single file inside the repo → a followable
      // source, so _BashLiveTail mounts a terminal instead of the muted note.
      await pumpWith(tester, [
        AssistantToolUse(uuid: 'bt', timestamp: _t, isSidechain: false, toolUseId: 'tbt', name: 'Bash', input: const {'command': 'tail -f app.log'}),
      ]);
      await tester.tap(find.bySemanticsLabel('Bash, 1 step, collapsed'));
      await tester.pumpAndSettle();

      // A resolvable source → the live tail surfaced, NOT the "nothing" note.
      expect(find.text('live tail'), findsOneWidget);
      expect(find.text('no independent source to follow'), findsNothing);
    });
  });

  group('ClaudeBanner', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    testWidgets('shows role, workspace, status, and a hint', (tester) async {
      await tester.pumpWidget(harness(f, const ClaudeBanner(role: 'primary', workspace: '/work/space', statusLine: 'tmux · clide-claude-x')));
      await tester.pump();
      expect(find.text('Claude'), findsOneWidget);
      expect(find.text('primary'), findsOneWidget);
      expect(find.text('/work/space'), findsOneWidget);
      expect(find.text('tmux · clide-claude-x'), findsOneWidget);
      expect(find.textContaining('Warming up'), findsOneWidget);
    });
  });
}
