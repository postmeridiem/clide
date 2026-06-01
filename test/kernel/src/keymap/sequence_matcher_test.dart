/// T-205 / D-82: multi-chord sequences, the stateless [Keymap.match]
/// query, and the stateful [SequenceMatcher] (prefix buffering, repeat
/// counts, the d-vs-dd timeout case, and broken-sequence recovery).
library;

import 'package:clide/kernel/src/keymap/intents.dart';
import 'package:clide/kernel/src/keymap/key_chord.dart';
import 'package:clide/kernel/src/keymap/keymap.dart';
import 'package:clide/kernel/src/keymap/sequence_matcher.dart';
import 'package:flutter/widgets.dart' show Intent;
import 'package:flutter_test/flutter_test.dart';

const _yaml = '''
name: t
bindings:
  - intent: command:del.pending
    keys: d
  - intent: command:del.line
    keys: 'd d'
  - intent: command:del.word
    keys: 'd w'
  - intent: command:goto.top
    keys: 'g g'
  - intent: command:down
    keys: j
  - intent: command:line.start
    keys: '0'
  - intent: command:del.char
    keys: x
  - intent: command:open
    keys: [ctrl+p, meta+p]
''';

String? _cmd(Intent? i) => i is InvokeCommandIntent ? i.commandId : null;

void main() {
  group('KeyChord.parseSequence', () {
    test('single chord → one element', () {
      expect(KeyChord.parseSequence('escape'), hasLength(1));
    });
    test('space separates a sequence', () {
      final seq = KeyChord.parseSequence('d d');
      expect(seq, hasLength(2));
      expect(seq[0], KeyChord.parse('d'));
      expect(seq[1], KeyChord.parse('d'));
    });
    test('chorded sequence (ctrl+k ctrl+s)', () {
      final seq = KeyChord.parseSequence('ctrl+k ctrl+s');
      expect(seq, hasLength(2));
      expect(seq[1], KeyChord.parse('ctrl+s'));
    });
    test('empty throws', () {
      expect(() => KeyChord.parseSequence('   '), throwsFormatException);
    });
  });

  group('KeyChord.digit', () {
    test('bare digit', () => expect(KeyChord.parse('5').digit, 5));
    test('letter is not a digit', () => expect(KeyChord.parse('j').digit, isNull));
    test('modified digit is not a count digit', () => expect(KeyChord.parse('ctrl+5').digit, isNull));
  });

  group('Keymap.match', () {
    late Keymap km;
    setUp(() => km = Keymap([KeymapLayer.fromYaml(_yaml)]));

    test('lone d is both an exact (del.pending) and a prefix (dd/dw)', () {
      final m = km.match([KeyChord.parse('d')], const {});
      expect(_cmd(m.exact), 'del.pending');
      expect(m.isPrefix, isTrue);
    });
    test('d d is an exact, not a prefix', () {
      final m = km.match(KeyChord.parseSequence('d d'), const {});
      expect(_cmd(m.exact), 'del.line');
      expect(m.isPrefix, isFalse);
    });
    test('g is a pure prefix (no single-g binding)', () {
      final m = km.match([KeyChord.parse('g')], const {});
      expect(m.exact, isNull);
      expect(m.isPrefix, isTrue);
    });
    test('unbound key matches nothing', () {
      final m = km.match([KeyChord.parse('z')], const {});
      expect(m.none, isTrue);
    });
  });

  group('SequenceMatcher', () {
    late SequenceMatcher matcher;
    setUp(() {
      final km = Keymap([KeymapLayer.fromYaml(_yaml)]);
      matcher = SequenceMatcher(keymap: () => km, context: () => const {});
    });

    SeqResult feed(String spec) => matcher.feed(KeyChord.parse(spec));

    test('completes d d → del.line', () {
      expect(feed('d').outcome, SeqOutcome.pending);
      final r = feed('d');
      expect(r.outcome, SeqOutcome.fired);
      expect(_cmd(r.intent), 'del.line');
      expect(r.count, 1);
    });

    test('completes d w → del.word', () {
      feed('d');
      expect(_cmd(feed('w').intent), 'del.word');
    });

    test('g g → goto.top', () {
      expect(feed('g').outcome, SeqOutcome.pending);
      expect(_cmd(feed('g').intent), 'goto.top');
    });

    test('single-chord binding fires immediately', () {
      final r = feed('j');
      expect(r.outcome, SeqOutcome.fired);
      expect(_cmd(r.intent), 'down');
    });

    test('repeat count: 5 j → down ×5', () {
      expect(feed('5').outcome, SeqOutcome.pending);
      final r = feed('j');
      expect(r.outcome, SeqOutcome.fired);
      expect(_cmd(r.intent), 'down');
      expect(r.count, 5);
    });

    test('multi-digit count accumulates', () {
      feed('1');
      feed('2');
      expect(feed('j').count, 12);
    });

    test('leading 0 is the line-start motion, not a count', () {
      final r = feed('0');
      expect(r.outcome, SeqOutcome.fired);
      expect(_cmd(r.intent), 'line.start');
      expect(r.count, 1);
    });

    test('unbound key passes through for insertion', () {
      final r = feed('z');
      expect(r.outcome, SeqOutcome.unmatched);
      expect(r.passKey, KeyChord.parse('z'));
    });

    test('d-then-flush fires the pending single-d binding', () {
      expect(feed('d').outcome, SeqOutcome.pending);
      final r = matcher.flush();
      expect(r.outcome, SeqOutcome.fired);
      expect(_cmd(r.intent), 'del.pending');
    });

    test('broken sequence restarts on the last chord', () {
      feed('d'); // pending (prefix of dd/dw)
      final r = feed('x'); // d x matches nothing → discard, retry x
      expect(r.outcome, SeqOutcome.fired);
      expect(_cmd(r.intent), 'del.char');
    });

    test('reset clears pending and count', () {
      feed('5');
      feed('d');
      expect(matcher.hasPending, isTrue);
      matcher.reset();
      expect(matcher.hasPending, isFalse);
      expect(matcher.pendingLength, 0);
    });

    test('flush with nothing buffered is a no-op', () {
      expect(matcher.flush().outcome, SeqOutcome.pending);
    });
  });
}
