/// Unit tests for the when-clause parser + evaluator.
library;

import 'package:clide/kernel/src/keymap/when_clause.dart';
import 'package:test/test.dart';

void main() {
  group('WhenExpr.parse — grammar', () {
    test('single identifier', () {
      final e = WhenExpr.parse('foo');
      expect(e, isA<WhenIdent>());
      expect(e.evaluate({'foo': true}), isTrue);
      expect(e.evaluate({'foo': false}), isFalse);
      expect(e.evaluate(const {}), isFalse, reason: 'missing identifier evaluates to false');
    });

    test('negation', () {
      final e = WhenExpr.parse('!foo');
      expect(e.evaluate({'foo': true}), isFalse);
      expect(e.evaluate({'foo': false}), isTrue);
      expect(e.evaluate(const {}), isTrue, reason: '!missing → true');
    });

    test('double negation', () {
      final e = WhenExpr.parse('!!foo');
      expect(e.evaluate({'foo': true}), isTrue);
      expect(e.evaluate({'foo': false}), isFalse);
    });

    test('conjunction is left-associative', () {
      final e = WhenExpr.parse('a && b && c');
      expect(e.evaluate({'a': true, 'b': true, 'c': true}), isTrue);
      expect(e.evaluate({'a': true, 'b': false, 'c': true}), isFalse);
    });

    test('disjunction is left-associative', () {
      final e = WhenExpr.parse('a || b || c');
      expect(e.evaluate({'a': false, 'b': false, 'c': true}), isTrue);
      expect(e.evaluate({'a': false, 'b': false, 'c': false}), isFalse);
    });

    test('and binds tighter than or', () {
      // a || b && c == a || (b && c)
      final e = WhenExpr.parse('a || b && c');
      expect(e.evaluate({'a': false, 'b': true, 'c': false}), isFalse);
      expect(e.evaluate({'a': false, 'b': true, 'c': true}), isTrue);
      expect(e.evaluate({'a': true, 'b': false, 'c': false}), isTrue);
    });

    test('parens override precedence', () {
      // (a || b) && c
      final e = WhenExpr.parse('(a || b) && c');
      expect(e.evaluate({'a': true, 'b': false, 'c': false}), isFalse);
      expect(e.evaluate({'a': true, 'b': false, 'c': true}), isTrue);
    });

    test('not binds tighter than and/or', () {
      // !a && b → (!a) && b
      final e = WhenExpr.parse('!a && b');
      expect(e.evaluate({'a': false, 'b': true}), isTrue);
      expect(e.evaluate({'a': true, 'b': true}), isFalse);
    });

    test('identifiers may contain dots, hyphens, underscores', () {
      final e = WhenExpr.parse('palette.is-open && _editor_focused');
      expect(e.evaluate({'palette.is-open': true, '_editor_focused': true}), isTrue);
    });

    test('whitespace is tolerated', () {
      final e = WhenExpr.parse('  a   &&   ( b || !c )  ');
      expect(e.evaluate({'a': true, 'b': true, 'c': true}), isTrue);
      expect(e.evaluate({'a': true, 'b': false, 'c': true}), isFalse);
    });
  });

  group('WhenExpr.parse — errors', () {
    test('empty input throws', () {
      expect(() => WhenExpr.parse(''), throwsFormatException);
    });

    test('unbalanced paren throws', () {
      expect(() => WhenExpr.parse('(a && b'), throwsFormatException);
    });

    test('trailing junk throws', () {
      expect(() => WhenExpr.parse('a && b foo'), throwsFormatException);
    });

    test('missing operand after operator throws', () {
      expect(() => WhenExpr.parse('a &&'), throwsFormatException);
    });

    test('bare ! throws', () {
      expect(() => WhenExpr.parse('!'), throwsFormatException);
    });
  });

  group('WhenExpr.tryParse', () {
    test('null and empty return null', () {
      expect(WhenExpr.tryParse(null), isNull);
      expect(WhenExpr.tryParse('   '), isNull);
    });

    test('non-empty delegates to parse', () {
      expect(WhenExpr.tryParse('foo'), isA<WhenIdent>());
    });
  });

  group('WhenExpr.toString', () {
    test('round-trips each node shape', () {
      expect(WhenExpr.parse('foo').toString(), 'foo');
      expect(WhenExpr.parse('!foo').toString(), '!foo');
      expect(WhenExpr.parse('a && b').toString(), '(a && b)');
      expect(WhenExpr.parse('a || b').toString(), '(a || b)');
    });
  });
}
