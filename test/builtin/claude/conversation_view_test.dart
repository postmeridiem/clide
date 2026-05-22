/// Widget tests for the native Claude ConversationView + controller
/// (T-137): renders each transcript item kind as a card, and text
/// selects + copies across cards via ClideSelectionArea (the terminal
/// affordance we keep, T-135).
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/conversation_view.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
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
      await Future<void>.delayed(Duration.zero);

      expect(c.items, hasLength(2));
      expect(c.items.first, isA<UserMessage>());
      expect(notifications, 2);
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
  });

  group('ConversationView', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

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
      await tester.pumpWidget(harness(f, ConversationView(controller: c)));
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
      expect(find.text('result'), findsOneWidget);
      expect(find.text('error'), findsOneWidget);
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
}
