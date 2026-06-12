/// Widget tests for [ModelPickerCard] — the bare `/model` interaction-zone
/// picker (T-408): rendering, current-model marking, number-key / arrow+Enter
/// selection, and Esc cancel.
library;

import 'package:clide/builtin/claude/src/model_picker_card.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

const models = [
  ModelOption(value: 'default', displayName: 'Default', description: 'recommended'),
  ModelOption(value: 'sonnet', displayName: 'Sonnet', description: 'fast'),
  ModelOption(value: 'opus', displayName: 'Opus', description: 'most capable'),
];

void main() {
  late KernelFixture f;

  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  group('modelOptionIsCurrent', () {
    test('matches by exact value or alias containment, never for default', () {
      const sonnet = ModelOption(value: 'sonnet', displayName: 'Sonnet');
      expect(modelOptionIsCurrent(sonnet, 'sonnet'), isTrue);
      expect(modelOptionIsCurrent(sonnet, 'claude-sonnet-4-6'), isTrue);
      expect(modelOptionIsCurrent(sonnet, 'claude-opus-4-8'), isFalse);
      expect(modelOptionIsCurrent(sonnet, null), isFalse);
      expect(modelOptionIsCurrent(const ModelOption(value: 'default', displayName: 'Default'), 'claude-opus-4-8'), isFalse);
    });
  });

  testWidgets('renders every model with the current one marked', (tester) async {
    await tester.pumpWidget(harness(f, ModelPickerCard(models: models, currentModel: 'claude-sonnet-4-6', onPick: (_) {}, onCancel: () {})));
    expect(find.textContaining('Default'), findsOneWidget);
    expect(find.textContaining('● Sonnet'), findsOneWidget); // current
    expect(find.textContaining('○ Opus'), findsOneWidget);
    expect(find.textContaining('most capable'), findsOneWidget);
  });

  testWidgets('tapping an entry picks its value', (tester) async {
    String? picked;
    await tester.pumpWidget(harness(f, ModelPickerCard(models: models, currentModel: null, onPick: (v) => picked = v, onCancel: () {})));
    await tester.tap(find.textContaining('Opus'));
    await tester.pump();
    expect(picked, 'opus');
  });

  testWidgets('a number key picks directly', (tester) async {
    String? picked;
    await tester.pumpWidget(harness(f, ModelPickerCard(models: models, currentModel: null, onPick: (v) => picked = v, onCancel: () {})));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    expect(picked, 'sonnet');
  });

  testWidgets('arrows move the highlight and Enter picks it', (tester) async {
    String? picked;
    await tester.pumpWidget(harness(f, ModelPickerCard(models: models, currentModel: 'claude-sonnet-4-6', onPick: (v) => picked = v, onCancel: () {})));
    // Highlight starts on the current model (sonnet, index 1).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // → opus
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(picked, 'opus');
  });

  testWidgets('Esc cancels without picking', (tester) async {
    String? picked;
    var cancelled = false;
    await tester.pumpWidget(harness(f, ModelPickerCard(models: models, currentModel: null, onPick: (v) => picked = v, onCancel: () => cancelled = true)));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(cancelled, isTrue);
    expect(picked, isNull);
  });

  testWidgets('an out-of-range number key is ignored', (tester) async {
    String? picked;
    await tester.pumpWidget(harness(f, ModelPickerCard(models: models, currentModel: null, onPick: (v) => picked = v, onCancel: () {})));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await tester.pump();
    expect(picked, isNull);
  });
}
