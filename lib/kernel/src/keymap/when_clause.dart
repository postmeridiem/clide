/// Boolean "when:" expressions over a named context bag, VS-Code style.
///
/// Grammar:
///   expr  := or
///   or    := and ('||' and)*
///   and   := unary ('&&' unary)*
///   unary := '!' unary | atom
///   atom  := IDENT | '(' expr ')'
///   IDENT := [a-zA-Z_][a-zA-Z0-9._-]*
///
/// Identifiers resolve against a `Map<String, bool>` context. A missing
/// identifier evaluates to `false` — bindings can assume any required
/// scope flag is published by the producing service.
///
/// The grammar is intentionally small: no equality, no arithmetic, no
/// string literals. If a binding needs more, the producing service
/// should publish a richer named flag (e.g. `editor.dirty`).
library;

import 'package:flutter/foundation.dart';

@immutable
sealed class WhenExpr {
  const WhenExpr();

  /// Evaluate against [context]. Missing identifiers are `false`.
  bool evaluate(Map<String, bool> context);

  /// Parse [source]. Throws [FormatException] on syntax errors.
  static WhenExpr parse(String source) => _Parser(source).parseAll();

  /// Convenience: null on empty input, otherwise [parse].
  static WhenExpr? tryParse(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    return parse(source);
  }
}

class WhenIdent extends WhenExpr {
  const WhenIdent(this.name);
  final String name;
  @override
  bool evaluate(Map<String, bool> context) => context[name] ?? false;
  @override
  String toString() => name;
}

class WhenNot extends WhenExpr {
  const WhenNot(this.child);
  final WhenExpr child;
  @override
  bool evaluate(Map<String, bool> context) => !child.evaluate(context);
  @override
  String toString() => '!$child';
}

class WhenAnd extends WhenExpr {
  const WhenAnd(this.left, this.right);
  final WhenExpr left;
  final WhenExpr right;
  @override
  bool evaluate(Map<String, bool> context) => left.evaluate(context) && right.evaluate(context);
  @override
  String toString() => '($left && $right)';
}

class WhenOr extends WhenExpr {
  const WhenOr(this.left, this.right);
  final WhenExpr left;
  final WhenExpr right;
  @override
  bool evaluate(Map<String, bool> context) => left.evaluate(context) || right.evaluate(context);
  @override
  String toString() => '($left || $right)';
}

// -- Parser -----------------------------------------------------------------

class _Parser {
  _Parser(this._src);

  final String _src;
  int _pos = 0;

  WhenExpr parseAll() {
    _skip();
    final e = _or();
    _skip();
    if (_pos != _src.length) {
      throw FormatException('unexpected "${_src[_pos]}" at column ${_pos + 1} in when-clause: "$_src"');
    }
    return e;
  }

  WhenExpr _or() {
    var left = _and();
    while (_consume('||')) {
      final right = _and();
      left = WhenOr(left, right);
    }
    return left;
  }

  WhenExpr _and() {
    var left = _unary();
    while (_consume('&&')) {
      final right = _unary();
      left = WhenAnd(left, right);
    }
    return left;
  }

  WhenExpr _unary() {
    _skip();
    if (_consume('!')) {
      return WhenNot(_unary());
    }
    return _atom();
  }

  WhenExpr _atom() {
    _skip();
    if (_consume('(')) {
      final inner = _or();
      _skip();
      if (!_consume(')')) {
        throw FormatException('expected ")" at column ${_pos + 1} in when-clause: "$_src"');
      }
      return inner;
    }
    final ident = _ident();
    if (ident == null) {
      final at = _pos < _src.length ? '"${_src[_pos]}"' : 'end of input';
      throw FormatException('expected identifier at column ${_pos + 1} in when-clause: "$_src" (got $at)');
    }
    return WhenIdent(ident);
  }

  String? _ident() {
    _skip();
    final start = _pos;
    if (_pos >= _src.length) return null;
    final first = _src.codeUnitAt(_pos);
    if (!_isIdentStart(first)) return null;
    _pos++;
    while (_pos < _src.length && _isIdentCont(_src.codeUnitAt(_pos))) {
      _pos++;
    }
    return _src.substring(start, _pos);
  }

  bool _consume(String token) {
    _skip();
    if (_src.startsWith(token, _pos)) {
      _pos += token.length;
      return true;
    }
    return false;
  }

  void _skip() {
    while (_pos < _src.length && _isSpace(_src.codeUnitAt(_pos))) {
      _pos++;
    }
  }
}

bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

bool _isIdentStart(int c) {
  // a-z | A-Z | _
  return (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) || c == 0x5F;
}

bool _isIdentCont(int c) {
  // a-z | A-Z | 0-9 | _ . -
  return _isIdentStart(c) || (c >= 0x30 && c <= 0x39) || c == 0x2E || c == 0x2D;
}
