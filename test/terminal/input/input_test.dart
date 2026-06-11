/// Pure-Dart tests for `lib/src/terminal/src/core/input/`.
///
/// Covers the keytab tokenizer + parser, the unescape helper, the
/// KeytabRecord toString shapes, the `Keytab.find` modifier-matching
/// rules, and the four `TerminalInputHandler` implementations.
library;

import 'package:clide/src/terminal/src/core/input/handler.dart';
import 'package:clide/src/terminal/src/core/input/keys.dart';
import 'package:clide/src/terminal/src/core/input/keytab/keytab.dart';
import 'package:clide/src/terminal/src/core/input/keytab/keytab_escape.dart';
import 'package:clide/src/terminal/src/core/input/keytab/keytab_parse.dart';
import 'package:clide/src/terminal/src/core/input/keytab/keytab_record.dart';
import 'package:clide/src/terminal/src/core/input/keytab/keytab_token.dart';
import 'package:clide/src/terminal/src/core/mouse/mode.dart';
import 'package:clide/src/terminal/src/core/cursor.dart';
import 'package:clide/src/terminal/src/core/platform.dart';
import 'package:clide/src/terminal/src/core/state.dart';
import 'package:test/test.dart';

class _State implements TerminalState {
  _State({this.lineFeedMode = false, this.appKeypadMode = false});

  @override
  bool lineFeedMode;
  @override
  bool appKeypadMode;

  @override
  int get viewWidth => 80;
  @override
  int get viewHeight => 24;
  @override
  CursorStyle get cursor => CursorStyle();
  @override
  bool get reflowEnabled => false;
  @override
  bool get insertMode => false;
  @override
  bool get cursorKeysMode => false;
  @override
  bool get reverseDisplayMode => false;
  @override
  bool get originMode => false;
  @override
  bool get autoWrapMode => true;
  @override
  MouseMode get mouseMode => MouseMode.none;
  @override
  MouseReportMode get mouseReportMode => MouseReportMode.normal;
  @override
  bool get cursorBlinkMode => true;
  @override
  bool get cursorVisibleMode => true;
  @override
  bool get reportFocusMode => false;
  @override
  bool get altBufferMouseScrollMode => false;
  @override
  bool get bracketedPasteMode => false;
}

TerminalKeyboardEvent _evt(
  TerminalKey key, {
  bool ctrl = false,
  bool alt = false,
  bool shift = false,
  bool altBuffer = false,
  bool lineFeedMode = false,
  bool appKeypadMode = false,
  TerminalTargetPlatform platform = TerminalTargetPlatform.linux,
}) {
  return TerminalKeyboardEvent(
    key: key,
    shift: shift,
    ctrl: ctrl,
    alt: alt,
    state: _State(lineFeedMode: lineFeedMode, appKeypadMode: appKeypadMode),
    altBuffer: altBuffer,
    platform: platform,
  );
}

void main() {
  group('keytabUnescape', () {
    test(r'\E maps to ESC (0x1b)', () {
      expect(keytabUnescape(r'\E'), '\x1b');
      expect(keytabUnescape(r'\E[A'), '\x1b[A');
    });

    test('classic backslash escapes round-trip', () {
      expect(keytabUnescape(r'\\'), r'\');
      expect(keytabUnescape(r'\"'), '"');
      expect(keytabUnescape(r'\t'), '\t');
      expect(keytabUnescape(r'\r'), '\r');
      expect(keytabUnescape(r'\n'), '\n');
      expect(keytabUnescape(r'\b'), '\b');
    });

    test(r'\xHH parses two hex digits to a single char', () {
      expect(keytabUnescape(r'\x00'), '\x00');
      expect(keytabUnescape(r'\x7f'), '\x7f');
      expect(keytabUnescape(r'\xFF'), 'ÿ');
    });

    test(r'leaves unrecognised text alone', () {
      expect(keytabUnescape('hello'), 'hello');
      expect(keytabUnescape(''), '');
    });
  });

  group('LineReader', () {
    test('peek/take advance + done detection', () {
      final r = LineReader('abc');
      expect(r.peek(), 'a');
      expect(r.take(), 'a');
      expect(r.peek(2), 'bc');
      expect(r.take(2), 'bc');
      expect(r.done, isTrue);
      expect(r.peek(), isNull);
      expect(r.take(), isNull);
    });

    test('peek clamps when count exceeds remaining length', () {
      final r = LineReader('ab');
      expect(r.peek(99), 'ab');
    });

    test('skipWhitespace eats spaces and tabs but stops on other chars', () {
      final r = LineReader('  \t  hello');
      r.skipWhitespace();
      expect(r.peek(5), 'hello');
    });

    test('readString takes alphanumeric / underscore until break', () {
      final r = LineReader('abc_123 next');
      expect(r.readString(), 'abc_123');
      // Position should now be at the space.
      expect(r.peek(), ' ');
    });

    test('readUntil takes everything up to the pattern (exclusive by default)', () {
      final r = LineReader('foo"bar');
      expect(r.readUntil('"'), 'foo');
      expect(r.peek(), '"');
    });

    test('readUntil with inclusive=true consumes the boundary char', () {
      final r = LineReader('foo"bar');
      expect(r.readUntil('"', inclusive: true), 'foo"');
      expect(r.peek(), 'b');
    });
  });

  group('tokenize', () {
    test('parses a keyboard-name line', () {
      final tokens = tokenize('keyboard "Default"').toList();
      expect(tokens.map((t) => t.type).toList(), [KeytabTokenType.keyboard, KeytabTokenType.input]);
      expect(tokens.last.value, 'Default');
    });

    test('parses a key-define line with modes and string action', () {
      final tokens = tokenize('key Up -Shift+Ansi : "\\EOA"').toList();
      expect(tokens.map((t) => t.type).toList(), [
        KeytabTokenType.keyDefine,
        KeytabTokenType.keyName,
        KeytabTokenType.modeStatus,
        KeytabTokenType.mode,
        KeytabTokenType.modeStatus,
        KeytabTokenType.mode,
        KeytabTokenType.colon,
        KeytabTokenType.input,
      ]);
      expect(tokens[1].value, 'Up');
      expect(tokens.last.value, r'\EOA');
    });

    test('parses a shortcut action (no quotes)', () {
      final tokens = tokenize('key Up +Shift : scrollLineUp').toList();
      expect(tokens.last.type, KeytabTokenType.shortcut);
      expect(tokens.last.value, 'scrollLineUp');
    });

    test('skips comments and blank lines', () {
      final source = '''
# top comment
keyboard "X"

# inner
key Tab : "\\t"  # trailing comment
''';
      final tokens = tokenize(source).toList();
      // Trailing-comment stripping leaves no broken tokens.
      expect(tokens.map((t) => t.type).toList(), contains(KeytabTokenType.colon));
    });

    test('tokenize throws TokenizeError on a malformed key line missing colon', () {
      expect(() => tokenize('key Tab "\\t"').toList(), throwsA(isA<TokenizeError>()));
    });

    test('tokenize throws TokenizeError on unterminated keyboard line', () {
      expect(() => tokenize('keyboard X').toList(), throwsA(isA<TokenizeError>()));
    });

    test('KeytabToken toString reflects type + value', () {
      final tok = KeytabToken(KeytabTokenType.input, 'hello');
      expect(tok.toString(), 'KeytabTokenType.input<hello>');
    });
  });

  group('KeytabParser', () {
    test('parses a keyboard name + a key-define line into a Keytab', () {
      const src = '''
keyboard "Test"
key Up -Shift+Ansi : "\\EOA"
''';
      final t = Keytab.parse(src);
      expect(t.name, 'Test');
      expect(t.records, hasLength(1));
      expect(t.records.first.qtKeyName, 'Up');
      expect(t.records.first.shift, isFalse);
      expect(t.records.first.ansi, isTrue);
    });

    test('every supported mode label maps to its KeytabRecord field', () {
      const src = '''
keyboard "Modes"
key Up +Alt+Control+Shift+AnyMod+Ansi+AppScreen+KeyPad+AppCuKeys+AppKeyPad+NewLine+Mac : "x"
''';
      final t = Keytab.parse(src);
      final r = t.records.single;
      expect(r.alt, isTrue);
      expect(r.ctrl, isTrue);
      expect(r.shift, isTrue);
      expect(r.anyModifier, isTrue);
      expect(r.ansi, isTrue);
      expect(r.appScreen, isTrue);
      expect(r.keyPad, isTrue);
      expect(r.appCursorKeys, isTrue);
      expect(r.appKeyPad, isTrue);
      expect(r.newLine, isTrue);
      expect(r.macos, isTrue);
    });

    test('parser throws ParseError on an unknown qt key name', () {
      const src = '''
keyboard "X"
key NotARealKey : "x"
''';
      expect(() => Keytab.parse(src), throwsA(isA<ParseError>()));
    });

    test('parser throws ParseError on an unknown mode label', () {
      const src = '''
keyboard "X"
key Up +Bogus : "x"
''';
      expect(() => Keytab.parse(src), throwsA(isA<ParseError>()));
    });

    test('TokensReader peek/take semantics', () {
      final a = KeytabToken(KeytabTokenType.colon, ':');
      final b = KeytabToken(KeytabTokenType.colon, ':');
      final r = TokensReader([a, b]);
      expect(r.peek(), a);
      expect(r.take(), a);
      expect(r.peek(), b);
      expect(r.take(), b);
      expect(r.done, isTrue);
      expect(r.peek(), isNull);
    });
  });

  group('KeytabRecord / KeytabAction toString', () {
    test('action toString quotes input and bare-prints shortcut', () {
      expect(KeytabAction(KeytabActionType.input, r'\E[A').toString(), '"\\E[A"');
      expect(KeytabAction(KeytabActionType.shortcut, 'scrollUp').toString(), 'scrollUp');
    });

    test('record toString writes +Mode for true and -Mode for false flags', () {
      final r = KeytabRecord(
        qtKeyName: 'Up',
        key: TerminalKey.arrowUp,
        action: KeytabAction(KeytabActionType.shortcut, 'scrollLineUp'),
        alt: true,
        ctrl: false,
        shift: null,
        anyModifier: null,
        ansi: true,
        appScreen: false,
        keyPad: null,
        appCursorKeys: null,
        appKeyPad: null,
        newLine: null,
        macos: null,
      );
      final s = r.toString();
      expect(s, contains('+Alt'));
      expect(s, contains('-Control'));
      expect(s, contains('+Ansi'));
      expect(s, contains('-AppScreen'));
      expect(s, isNot(contains('Shift')));
      expect(s, endsWith(': scrollLineUp'));
    });

    test('Keytab toString lists name + records', () {
      const src = '''
keyboard "Listed"
key Up +Shift : scrollLineUp
''';
      final t = Keytab.parse(src);
      final s = t.toString();
      expect(s, contains('keyboard "Listed"'));
      expect(s, contains('Up'));
      expect(s, contains('scrollLineUp'));
    });

    test('action unescapedValue returns the raw value for shortcut actions', () {
      // Input actions go through keytabUnescape; shortcut actions don't.
      expect(KeytabAction(KeytabActionType.shortcut, r'\Ehello').unescapedValue(), r'\Ehello');
    });

    test('record toString covers every supported mode flag when set', () {
      // Sets every nullable flag so each `if (foo != null)` branch fires.
      final r = KeytabRecord(
        qtKeyName: 'Up',
        key: TerminalKey.arrowUp,
        action: KeytabAction(KeytabActionType.input, 'x'),
        alt: true,
        ctrl: true,
        shift: false,
        anyModifier: true,
        ansi: true,
        appScreen: false,
        keyPad: true,
        appCursorKeys: false,
        appKeyPad: true,
        newLine: false,
        macos: true,
      );
      final s = r.toString();
      expect(s, contains('+Alt'));
      expect(s, contains('+Control'));
      expect(s, contains('-Shift'));
      expect(s, contains('+AnyMod'));
      expect(s, contains('+Ansi'));
      expect(s, contains('-AppScreen'));
      expect(s, contains('+KeyPad'));
      expect(s, contains('-AppCuKeys'));
      expect(s, contains('+AppKeyPad'));
      expect(s, contains('-NewLine'));
      expect(s, contains('+Mac'));
      expect(s, endsWith(': "x"'));
    });
  });

  group('KeytabParser — defensive error paths through hand-crafted tokens', () {
    test('addTokens throws ParseError on a stray non-keyboard / non-keyDefine token', () {
      final parser = KeytabParser();
      expect(() => parser.addTokens([KeytabToken(KeytabTokenType.colon, ':')]), throwsA(isA<ParseError>()));
    });

    test('_parseName throws when the second token is not an input token', () {
      final parser = KeytabParser();
      expect(
        () => parser.addTokens([KeytabToken(KeytabTokenType.keyboard, 'keyboard'), KeytabToken(KeytabTokenType.keyName, 'Up')]),
        throwsA(isA<ParseError>()),
      );
    });

    test('_parseKeyDefine throws when the second token is not a keyName', () {
      final parser = KeytabParser();
      expect(() => parser.addTokens([KeytabToken(KeytabTokenType.keyDefine, 'key'), KeytabToken(KeytabTokenType.colon, ':')]), throwsA(isA<ParseError>()));
    });

    test('_parseKeyDefine throws on an unrecognised modeStatus value', () {
      final parser = KeytabParser();
      expect(
        () => parser.addTokens([
          KeytabToken(KeytabTokenType.keyDefine, 'key'),
          KeytabToken(KeytabTokenType.keyName, 'Up'),
          KeytabToken(KeytabTokenType.modeStatus, 'X'), // not '+' / '-'
        ]),
        throwsA(isA<ParseError>()),
      );
    });

    test('_parseKeyDefine throws when the token after modeStatus is not a mode', () {
      final parser = KeytabParser();
      expect(
        () => parser.addTokens([
          KeytabToken(KeytabTokenType.keyDefine, 'key'),
          KeytabToken(KeytabTokenType.keyName, 'Up'),
          KeytabToken(KeytabTokenType.modeStatus, '+'),
          KeytabToken(KeytabTokenType.colon, ':'), // not a mode token
        ]),
        throwsA(isA<ParseError>()),
      );
    });

    test('_parseKeyDefine throws when the colon is missing', () {
      final parser = KeytabParser();
      expect(
        () => parser.addTokens([
          KeytabToken(KeytabTokenType.keyDefine, 'key'),
          KeytabToken(KeytabTokenType.keyName, 'Up'),
          KeytabToken(KeytabTokenType.input, 'x'), // should be colon here
        ]),
        throwsA(isA<ParseError>()),
      );
    });

    test('_parseKeyDefine throws when the action token is neither input nor shortcut', () {
      final parser = KeytabParser();
      expect(
        () => parser.addTokens([
          KeytabToken(KeytabTokenType.keyDefine, 'key'),
          KeytabToken(KeytabTokenType.keyName, 'Up'),
          KeytabToken(KeytabTokenType.colon, ':'),
          KeytabToken(KeytabTokenType.mode, 'Alt'), // not a valid action
        ]),
        throwsA(isA<ParseError>()),
      );
    });
  });

  group('Keytab.find — modifier matching', () {
    Keytab build(String src) => Keytab.parse('keyboard "X"\n$src\n');

    test('exact match: -Shift on a record with shift=null and no anyModifier', () {
      final t = build('key Up -Shift : "\\E[A"');
      expect(t.find(TerminalKey.arrowUp, shift: false)?.action.value, r'\E[A');
      expect(t.find(TerminalKey.arrowUp, shift: true), isNull);
    });

    test('+AnyMod requires at least one modifier; rejects no-modifier press', () {
      final t = build('key Up +AnyMod : "\\E[A"');
      expect(t.find(TerminalKey.arrowUp), isNull);
      expect(t.find(TerminalKey.arrowUp, ctrl: true), isNotNull);
    });

    test('-AnyMod requires zero modifiers; rejects any-modifier press', () {
      final t = build('key Up -AnyMod : "\\E[A"');
      expect(t.find(TerminalKey.arrowUp), isNotNull);
      expect(t.find(TerminalKey.arrowUp, alt: true), isNull);
    });

    test('mode flags filter records (newLine + appKeyPad + appScreen + macos)', () {
      final t = build('''
key Up +NewLine+AppKeyPad+AppScreen+Mac : "match"
key Up : "fallback"
''');
      // Wrong newLine mode falls through to fallback.
      expect(t.find(TerminalKey.arrowUp, newLineMode: false, appKeyPad: true, appScreen: true, macos: true)?.action.value, 'fallback');
      // All matching → primary record.
      expect(t.find(TerminalKey.arrowUp, newLineMode: true, appKeyPad: true, appScreen: true, macos: true)?.action.value, 'match');
    });

    test('-Ansi records are skipped (VT52 not supported yet)', () {
      final t = build('key Up -Ansi : "vt52"');
      expect(t.find(TerminalKey.arrowUp), isNull);
    });

    test('returns null when no record key matches', () {
      final t = build('key Up : "\\EA"');
      expect(t.find(TerminalKey.arrowDown), isNull);
    });

    test('appCursorKeys + keyPad gates also filter', () {
      final t = build('key Up +AppCuKeys+KeyPad : "\\EOA"\nkey Up : "fallback"');
      expect(t.find(TerminalKey.arrowUp)?.action.value, 'fallback');
      expect(t.find(TerminalKey.arrowUp, appCursorKeys: true, keyPad: true)?.action.value, r'\EOA');
    });
  });

  group('Default keytab is parsable + nontrivial', () {
    test('Keytab.defaultKeytab name + at least one record', () {
      expect(Keytab.defaultKeytab.name, isNotEmpty);
      expect(Keytab.defaultKeytab.records, isNotEmpty);
    });
  });

  group('TerminalKeyboardEvent', () {
    test('copyWith overrides only specified fields', () {
      final base = _evt(TerminalKey.arrowUp);
      final shifted = base.copyWith(shift: true);
      expect(shifted.shift, isTrue);
      expect(shifted.alt, base.alt);
      expect(shifted.ctrl, base.ctrl);
      expect(shifted.key, base.key);
      expect(shifted.platform, base.platform);
    });

    test('copyWith() with no args is equivalent to the original', () {
      final base = _evt(TerminalKey.arrowDown, alt: true);
      final clone = base.copyWith();
      expect(clone.key, base.key);
      expect(clone.alt, base.alt);
    });
  });

  group('CascadeInputHandler', () {
    test('returns the first non-null result; null otherwise', () {
      const cascade = CascadeInputHandler([
        _NullHandler(),
        _ConstHandler('first'),
        _ConstHandler('second'), // should never be reached
      ]);
      expect(cascade(_evt(TerminalKey.arrowUp)), 'first');

      const allNull = CascadeInputHandler([_NullHandler(), _NullHandler()]);
      expect(allNull(_evt(TerminalKey.arrowUp)), isNull);
    });
  });

  group('KeytabInputHandler', () {
    test('falls back to Keytab.defaultKeytab when none is supplied', () {
      // Up arrow with no modifiers → default keytab match (\E[A or similar
      // depending on mode flags). Just assert non-null.
      const h = KeytabInputHandler();
      expect(h(_evt(TerminalKey.arrowUp)), isNotNull);
    });

    test('returns null when the keytab has no matching record', () {
      final empty = Keytab(name: 'empty', records: const []);
      expect(KeytabInputHandler(empty)(_evt(TerminalKey.arrowUp)), isNull);
    });

    test('inserts a modifier code into actions containing *', () {
      // Build a keytab whose Up record uses the * placeholder; the handler
      // replaces * with a code based on the active modifiers.
      final t = Keytab.parse('keyboard "X"\nkey Up +AnyMod : "\\E[1;*A"\n');
      final h = KeytabInputHandler(t);

      final cases = <(TerminalKeyboardEvent, String)>[
        // Single-modifier codes.
        (_evt(TerminalKey.arrowUp, shift: true), '\x1b[1;2A'), // shift → 2
        (_evt(TerminalKey.arrowUp, alt: true), '\x1b[1;3A'), // alt → 3
        (_evt(TerminalKey.arrowUp, ctrl: true), '\x1b[1;5A'), // ctrl → 5
        // Pair codes.
        (_evt(TerminalKey.arrowUp, shift: true, alt: true), '\x1b[1;4A'),
        (_evt(TerminalKey.arrowUp, shift: true, ctrl: true), '\x1b[1;6A'),
        (_evt(TerminalKey.arrowUp, ctrl: true, alt: true), '\x1b[1;7A'),
        // Triple.
        (_evt(TerminalKey.arrowUp, shift: true, alt: true, ctrl: true), '\x1b[1;8A'),
      ];
      for (final c in cases) {
        expect(h(c.$1), c.$2, reason: '$c');
      }
    });

    test('leaves the action alone when no * placeholder is present', () {
      final t = Keytab.parse('keyboard "X"\nkey Up : "\\E[A"\n');
      final h = KeytabInputHandler(t);
      expect(h(_evt(TerminalKey.arrowUp)), '\x1b[A');
    });
  });

  group('CtrlInputHandler', () {
    const h = CtrlInputHandler();

    test('Ctrl+A through Ctrl+Z map to control bytes 0x01..0x1A', () {
      for (var i = 0; i < 26; i++) {
        final key = TerminalKey.values[TerminalKey.keyA.index + i];
        final result = h(_evt(key, ctrl: true));
        expect(result, String.fromCharCode(i + 1), reason: 'TerminalKey.${key.name} → ${i + 1}');
      }
    });

    test('returns null without ctrl, or when shift / alt are also pressed', () {
      expect(h(_evt(TerminalKey.keyA)), isNull);
      expect(h(_evt(TerminalKey.keyA, ctrl: true, shift: true)), isNull);
      expect(h(_evt(TerminalKey.keyA, ctrl: true, alt: true)), isNull);
    });

    test('returns null for non-letter keys', () {
      expect(h(_evt(TerminalKey.arrowUp, ctrl: true)), isNull);
      expect(h(_evt(TerminalKey.f1, ctrl: true)), isNull);
    });
  });

  group('AltInputHandler', () {
    const h = AltInputHandler();

    test('Alt+A through Alt+Z emit ESC + uppercase ASCII byte', () {
      for (var i = 0; i < 26; i++) {
        final key = TerminalKey.values[TerminalKey.keyA.index + i];
        final result = h(_evt(key, alt: true));
        expect(result, '\x1b${String.fromCharCode(0x41 + i)}');
      }
    });

    test('returns null without alt, or when shift / ctrl are also pressed', () {
      expect(h(_evt(TerminalKey.keyA)), isNull);
      expect(h(_evt(TerminalKey.keyA, alt: true, ctrl: true)), isNull);
      expect(h(_evt(TerminalKey.keyA, alt: true, shift: true)), isNull);
    });

    test('returns null on macOS (Alt is reserved for char composition)', () {
      expect(h(_evt(TerminalKey.keyA, alt: true, platform: TerminalTargetPlatform.macos)), isNull);
    });

    test('returns null for non-letter keys', () {
      expect(h(_evt(TerminalKey.arrowUp, alt: true)), isNull);
    });
  });

  group('defaultInputHandler', () {
    test('routes a plain Up arrow through the keytab', () {
      expect(defaultInputHandler(_evt(TerminalKey.arrowUp)), isNotNull);
    });

    test('routes Ctrl+C to 0x03 via CtrlInputHandler when keytab misses', () {
      // Default keytab has no entry for Ctrl+keyC, so CtrlInputHandler runs.
      expect(defaultInputHandler(_evt(TerminalKey.keyC, ctrl: true)), '\x03');
    });
  });
}

class _NullHandler implements TerminalInputHandler {
  const _NullHandler();
  @override
  String? call(TerminalKeyboardEvent event) => null;
}

class _ConstHandler implements TerminalInputHandler {
  const _ConstHandler(this._value);
  final String _value;
  @override
  String? call(TerminalKeyboardEvent event) => _value;
}
