import 'package:clide/kernel/src/keymap/intents.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseIntentId', () {
    test('returns null for an unknown id', () {
      expect(parseIntentId('not.a.real.intent'), isNull);
    });

    test('returns ActivateIntent for "activate"', () {
      expect(parseIntentId('activate'), isA<ActivateIntent>());
    });

    test('returns DismissIntent for "dismiss"', () {
      expect(parseIntentId('dismiss'), isA<DismissIntent>());
    });

    test('returns the focus.* intents', () {
      expect(parseIntentId('focus.nextPanel'), isA<FocusNextPanelIntent>());
      expect(parseIntentId('focus.previousPanel'), isA<FocusPreviousPanelIntent>());
    });

    test('returns the palette.* intents', () {
      expect(parseIntentId('palette.open'), isA<PaletteOpenIntent>());
      expect(parseIntentId('palette.selectNext'), isA<PaletteSelectNextIntent>());
      expect(parseIntentId('palette.selectPrevious'), isA<PaletteSelectPreviousIntent>());
      expect(parseIntentId('palette.accept'), isA<PaletteAcceptIntent>());
    });

    test('returns the text.scale* intents', () {
      expect(parseIntentId('text.scaleIncrease'), isA<TextScaleIncreaseIntent>());
      expect(parseIntentId('text.scaleDecrease'), isA<TextScaleDecreaseIntent>());
      expect(parseIntentId('text.scaleReset'), isA<TextScaleResetIntent>());
    });

    test('returns InvokeCommandIntent for "command:<id>" with the id stripped', () {
      final intent = parseIntentId('command:theme.pick');
      expect(intent, isA<InvokeCommandIntent>());
      expect((intent as InvokeCommandIntent).commandId, 'theme.pick');
    });

    test('returns InvokeCommandIntent with an empty commandId for "command:"', () {
      final intent = parseIntentId('command:');
      expect(intent, isA<InvokeCommandIntent>());
      expect((intent as InvokeCommandIntent).commandId, '');
    });
  });
}
