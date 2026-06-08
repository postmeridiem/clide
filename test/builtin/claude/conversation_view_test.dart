/// Widget tests for the native Claude ConversationView + controller
/// (T-137): renders each transcript item kind as a card, and text
/// selects + copies across cards via ClideSelectionArea (the terminal
/// affordance we keep, T-135).
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/activity_cluster.dart';
import 'package:clide/builtin/claude/src/claude_banner.dart';
import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/conversation_view.dart';
import 'package:clide/builtin/claude/src/transcript_publisher.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Image, FileImage;
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
ImageMessage _image(String path, {String? caption}) => ImageMessage(uuid: 'i', timestamp: _t, isSidechain: false, path: path, caption: caption);

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

    Future<ConversationController> pumpWith(WidgetTester tester, List<ConversationItem> items,
        {Set<String> hiddenToolUseIds = const {}, Map<String, bool> toolUseOutcomes = const {}, FoldLevel foldLevel = FoldLevel.none}) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final stream = StreamController<ConversationItem>.broadcast();
      final c = ConversationController(stream: stream.stream);
      addTearDown(c.dispose);
      await tester
          .pumpWidget(harness(f, ConversationView(controller: c, hiddenToolUseIds: hiddenToolUseIds, toolUseOutcomes: toolUseOutcomes, foldLevel: foldLevel)));
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

    testWidgets('meta items fold into a collapsed activity card; tap expands (T-230)', (tester) async {
      await pumpWith(
          tester,
          [
            _tool('Bash', const {'command': 'echo hi'}),
            // A second, distinct in-flight tool call (T-262 folds a success
            // result into its call card, so two *calls* are what make 2 steps).
            AssistantToolUse(uuid: 'tu2', timestamp: _t, isSidechain: false, toolUseId: 'x2', name: 'Read', input: const {'file_path': '/a'}),
          ],
          foldLevel: FoldLevel.tools);
      // Collapsed by default: one card with a step count, not the raw rows.
      expect(find.text('2 steps'), findsOneWidget);
      expect(find.bySemanticsLabel('Activity, 2 steps, collapsed'), findsOneWidget);
      // Activating it expands to reveal the folded steps.
      await tester.tap(find.bySemanticsLabel('Activity, 2 steps, collapsed'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Activity, 2 steps, expanded'), findsOneWidget);
    });

    testWidgets('a folded success result is not a separate step — merged into its call (T-262 note D)', (tester) async {
      await pumpWith(
          tester,
          [
            _tool('Bash', const {'command': 'echo hi'}),
            _result('hi there'),
          ],
          foldLevel: FoldLevel.tools);
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

    testWidgets('inject() drives a new image card into a live view (T-249)', (tester) async {
      final c = await pumpWith(tester, [_user('hi')]);
      expect(find.text('image'), findsNothing);
      c.inject(_image('/no/such/shot.png'));
      await tester.pumpAndSettle();
      expect(find.text('image'), findsOneWidget);
    });

    testWidgets('a failed result surfaces first-class, not folded (T-230)', (tester) async {
      await pumpWith(
          tester,
          [
            _tool('Bash', const {'command': 'boom'}),
            _result('error output', isError: true),
          ],
          foldLevel: FoldLevel.tools);
      // The tool call folds (1 step); the error result is sticky → no 2-step card.
      expect(find.text('1 step'), findsOneWidget);
      expect(find.textContaining('error output'), findsWidgets);
    });

    testWidgets('empty controller shows the provided emptyState instead', (tester) async {
      final stream = StreamController<ConversationItem>.broadcast();
      final c = ConversationController(stream: stream.stream);
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(
        f,
        ConversationView(
          controller: c,
          emptyState: const ClideText('CUSTOM EMPTY'),
        ),
      ));
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
            uuid: 'agt-msg', timestamp: _t, isSidechain: false, toolUseId: 'task1', name: 'Task', input: const {'description': 'explore the codebase'}),
        UserMessage(uuid: 'p1', timestamp: _t, isSidechain: true, text: 'find all the widgets'),
      ]);
      // Never the blue "you", and no standalone block (folded → suppressed).
      expect(find.text('you'), findsNothing);
      expect(find.text('agent prompt'), findsNothing); // not a standalone card here
      expect(find.text('Task'), findsOneWidget);
      // Collapsed by default: the prompt is hidden.
      expect(find.text('find all the widgets'), findsNothing);

      // Expand the Agent card → a "prompt" segment reveals the folded prompt.
      await tester.tap(find.bySemanticsLabel('Expand'));
      await tester.pumpAndSettle();
      expect(find.text('prompt'), findsOneWidget); // segment sub-label
      expect(find.text('find all the widgets'), findsOneWidget);
    });

    testWidgets('an orphan sidechain prompt renders as muted "agent prompt", never "you" (T-263)', (tester) async {
      // No Agent tool-use to attach to → stays standalone, but relabelled.
      await pumpWith(tester, [
        UserMessage(uuid: 'orphan', timestamp: _t, isSidechain: true, text: 'orphaned agent instructions'),
      ]);
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
      // Two collapsed Agent cards; the first Expand caret belongs to card A.
      expect(find.text('you'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Expand').first);
      await tester.pumpAndSettle();
      // Only card A is expanded → its prompt (A) shows; B's stays folded away.
      // Nearest-preceding would have put A's prompt under B, revealing nothing.
      expect(find.text('PROMPT FOR A'), findsOneWidget);
      expect(find.text('PROMPT FOR B'), findsNothing);
    });

    testWidgets('a permission-prompted tool-use is hidden but its result is kept', (tester) async {
      await pumpWith(
        tester,
        [
          _tool('Write', {'file_path': '/tmp/x'}),
          _result('done')
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
          _result('done')
        ],
        hiddenToolUseIds: {'x1'},
        toolUseOutcomes: {'x1': true}, // approved
      );
      final handle = tester.ensureSemantics();
      expect(find.text('Write'), findsOneWidget); // shown (resolved)
      expect(find.bySemanticsLabel('Expand'), findsOneWidget); // collapsed caret
      // T-262: the resolved card also folds its result + a success check.
      expect(find.bySemanticsLabel('succeeded'), findsOneWidget);
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
        _tool('Bash', {'command': 'ls -la'})
      ]);
      // Card starts collapsed — the command appears as the collapsed summary.
      expect(find.text('ls -la'), findsOneWidget);
      // Expand to verify the body is a bash code block.
      await tester.tap(find.byType(ClideIcon));
      await tester.pump();
      final blocks = tester.widgetList<ClideCodeBlock>(find.byType(ClideCodeBlock)).toList();
      expect(blocks.any((b) => b.language == 'bash' && b.source.contains('ls -la')), isTrue);
    });

    testWidgets('tool-use body: Read/Grep/LS shows a compact path label (T-168)', (tester) async {
      await pumpWith(tester, [
        _tool('Read', {'file_path': '/foo/bar.dart'})
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
      // The merged card shows a success check.
      expect(find.bySemanticsLabel('succeeded'), findsOneWidget);
      // Collapsed by default: neither the call body nor the result is shown yet.
      expect(find.text('final answer = 42;'), findsNothing);

      // Expand: the call segment, a "result" sub-label, and the folded result
      // as a colorized code block (Read → grammar from the .dart path).
      await tester.tap(find.bySemanticsLabel('Expand'));
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
        _tool('Bash', {'command': 'ls'})
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
      await tester.tap(find.bySemanticsLabel('Expand'));
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
      // …and the call card carries a red failure mark for symmetry (note C).
      expect(find.bySemanticsLabel('failed'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('error result label includes paired tool name (T-168)', (tester) async {
      await pumpWith(tester, [
        _tool('Bash', {'command': 'cat nonexistent'}),
        _result('No such file', isError: true),
      ]);
      expect(find.text('Bash · error'), findsOneWidget);
    });

    testWidgets('result without a paired tool_use uses plain "result" label (T-168)', (tester) async {
      // Orphan result (no matching tool_use in the controller).
      await pumpWith(tester, [
        ToolResultMessage(
          uuid: 'r-orphan',
          timestamp: _t,
          isSidechain: false,
          toolUseId: 'unknown-id',
          content: 'ok',
          isError: false,
        ),
      ]);
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
  });

  group('ClaudeBanner', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    testWidgets('shows role, workspace, status, and a hint', (tester) async {
      await tester.pumpWidget(harness(
        f,
        const ClaudeBanner(
          role: 'primary',
          workspace: '/work/space',
          statusLine: 'tmux · clide-claude-x',
        ),
      ));
      await tester.pump();
      expect(find.text('Claude'), findsOneWidget);
      expect(find.text('primary'), findsOneWidget);
      expect(find.text('/work/space'), findsOneWidget);
      expect(find.text('tmux · clide-claude-x'), findsOneWidget);
      expect(find.textContaining('Warming up'), findsOneWidget);
    });
  });
}
