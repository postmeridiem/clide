/// SVG `path` `d`-attribute parser (T-320 / D-103).
///
/// Parses SVG path data into a flat list of [SvgPathSeg]s in ABSOLUTE
/// coordinates, lowering the SVG shorthands to a small command set the painter
/// can replay straight onto a `dart:ui` Path:
///   - relative (lower-case) commands → absolute
///   - `H`/`V` → [SvgPathOp.lineTo]
///   - `S` → [SvgPathOp.cubicTo] (first control reflected from the previous cubic)
///   - `T` → [SvgPathOp.quadTo]  (control reflected from the previous quadratic)
///   - arcs (`A`) kept as [SvgPathOp.arcTo] for the painter to realise
///
/// Tolerant by construction: malformed tail input stops the parse and returns
/// what was understood so far — a broken `d` never throws, so a bad diagram
/// can't crash the conversation. No dependency, per prefer-zero-deps.
///
/// Flutter-free: pure Dart, runs under `dart test`. The painter (Flutter)
/// consumes [SvgPathSeg] and builds the actual Path.
library;

/// The painter-facing path command set the parser lowers SVG path data to.
enum SvgPathOp { moveTo, lineTo, cubicTo, quadTo, arcTo, close }

/// One absolute-coordinate path segment.
///
/// [args] layout by [op]:
///   - moveTo / lineTo : `[x, y]`
///   - cubicTo         : `[x1, y1, x2, y2, x, y]`
///   - quadTo          : `[x1, y1, x, y]`
///   - arcTo           : `[rx, ry, xAxisRotationDeg, largeArc, sweep, x, y]`
///     (largeArc / sweep are `0.0` or `1.0`)
///   - close           : `[]`
class SvgPathSeg {
  final SvgPathOp op;
  final List<double> args;
  const SvgPathSeg(this.op, this.args);

  @override
  bool operator ==(Object other) {
    if (other is! SvgPathSeg || other.op != op || other.args.length != args.length) {
      return false;
    }
    for (var i = 0; i < args.length; i++) {
      if (other.args[i] != args[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(op, Object.hashAll(args));

  @override
  String toString() => '${op.name}(${args.join(', ')})';
}

/// Parse an SVG `path` `d` attribute into absolute segments. Returns whatever
/// was understood up to the first unrecoverable token; never throws.
List<SvgPathSeg> parseSvgPath(String d) {
  final out = <SvgPathSeg>[];
  final sc = _Scanner(d);

  double cx = 0, cy = 0; // current point
  double sx = 0, sy = 0; // subpath start (target of Z)
  double? cubX, cubY; // previous cubic's 2nd control (for S reflection)
  double? quadX, quadY; // previous quadratic's control (for T reflection)
  String prev = '';

  sc.skipSep();
  while (!sc.atEnd) {
    final loopStart = sc.i;
    final ch = sc.s[sc.i];
    final explicit = _isCmd(ch);
    String cmd;
    if (explicit) {
      cmd = ch;
      sc.i++;
    } else if (prev.isNotEmpty) {
      // Implicit repeat of the previous command; an initial M/m repeats as L/l.
      cmd = prev == 'M' ? 'L' : (prev == 'm' ? 'l' : prev);
    } else {
      break; // data must open with a command
    }
    // Z carries no parameters, so it never repeats implicitly.
    if (!explicit && (cmd == 'Z' || cmd == 'z')) break;

    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        final x = sc.num_(), y = sc.num_();
        if (x == null || y == null) return out;
        cx = rel ? cx + x : x;
        cy = rel ? cy + y : y;
        sx = cx;
        sy = cy;
        out.add(SvgPathSeg(SvgPathOp.moveTo, [cx, cy]));
        cubX = cubY = quadX = quadY = null;
      case 'L':
        final x = sc.num_(), y = sc.num_();
        if (x == null || y == null) return out;
        cx = rel ? cx + x : x;
        cy = rel ? cy + y : y;
        out.add(SvgPathSeg(SvgPathOp.lineTo, [cx, cy]));
        cubX = cubY = quadX = quadY = null;
      case 'H':
        final x = sc.num_();
        if (x == null) return out;
        cx = rel ? cx + x : x;
        out.add(SvgPathSeg(SvgPathOp.lineTo, [cx, cy]));
        cubX = cubY = quadX = quadY = null;
      case 'V':
        final y = sc.num_();
        if (y == null) return out;
        cy = rel ? cy + y : y;
        out.add(SvgPathSeg(SvgPathOp.lineTo, [cx, cy]));
        cubX = cubY = quadX = quadY = null;
      case 'C':
        final x1 = sc.num_(), y1 = sc.num_();
        final x2 = sc.num_(), y2 = sc.num_();
        final x = sc.num_(), y = sc.num_();
        if (x1 == null || y1 == null || x2 == null || y2 == null || x == null || y == null) {
          return out;
        }
        final ax1 = rel ? cx + x1 : x1, ay1 = rel ? cy + y1 : y1;
        final ax2 = rel ? cx + x2 : x2, ay2 = rel ? cy + y2 : y2;
        final ax = rel ? cx + x : x, ay = rel ? cy + y : y;
        out.add(SvgPathSeg(SvgPathOp.cubicTo, [ax1, ay1, ax2, ay2, ax, ay]));
        cubX = ax2;
        cubY = ay2;
        quadX = quadY = null;
        cx = ax;
        cy = ay;
      case 'S':
        final x2 = sc.num_(), y2 = sc.num_();
        final x = sc.num_(), y = sc.num_();
        if (x2 == null || y2 == null || x == null || y == null) return out;
        final rx = cubX != null ? 2 * cx - cubX : cx;
        final ry = cubY != null ? 2 * cy - cubY : cy;
        final ax2 = rel ? cx + x2 : x2, ay2 = rel ? cy + y2 : y2;
        final ax = rel ? cx + x : x, ay = rel ? cy + y : y;
        out.add(SvgPathSeg(SvgPathOp.cubicTo, [rx, ry, ax2, ay2, ax, ay]));
        cubX = ax2;
        cubY = ay2;
        quadX = quadY = null;
        cx = ax;
        cy = ay;
      case 'Q':
        final x1 = sc.num_(), y1 = sc.num_();
        final x = sc.num_(), y = sc.num_();
        if (x1 == null || y1 == null || x == null || y == null) return out;
        final ax1 = rel ? cx + x1 : x1, ay1 = rel ? cy + y1 : y1;
        final ax = rel ? cx + x : x, ay = rel ? cy + y : y;
        out.add(SvgPathSeg(SvgPathOp.quadTo, [ax1, ay1, ax, ay]));
        quadX = ax1;
        quadY = ay1;
        cubX = cubY = null;
        cx = ax;
        cy = ay;
      case 'T':
        final x = sc.num_(), y = sc.num_();
        if (x == null || y == null) return out;
        final rx = quadX != null ? 2 * cx - quadX : cx;
        final ry = quadY != null ? 2 * cy - quadY : cy;
        final ax = rel ? cx + x : x, ay = rel ? cy + y : y;
        out.add(SvgPathSeg(SvgPathOp.quadTo, [rx, ry, ax, ay]));
        quadX = rx;
        quadY = ry;
        cubX = cubY = null;
        cx = ax;
        cy = ay;
      case 'A':
        final rx = sc.num_(), ry = sc.num_(), rot = sc.num_();
        final laf = sc.flag(), swf = sc.flag();
        final x = sc.num_(), y = sc.num_();
        if (rx == null || ry == null || rot == null || laf == null || swf == null || x == null || y == null) {
          return out;
        }
        final ax = rel ? cx + x : x, ay = rel ? cy + y : y;
        out.add(SvgPathSeg(SvgPathOp.arcTo, [rx.abs(), ry.abs(), rot, laf.toDouble(), swf.toDouble(), ax, ay]));
        cubX = cubY = quadX = quadY = null;
        cx = ax;
        cy = ay;
      case 'Z':
        out.add(const SvgPathSeg(SvgPathOp.close, []));
        cx = sx;
        cy = sy;
        cubX = cubY = quadX = quadY = null;
      default:
        return out; // unknown command letter
    }

    prev = cmd;
    sc.skipSep();
    if (sc.i == loopStart) break; // no progress (e.g. implicit repeat of Z) — bail
  }
  return out;
}

bool _isCmd(String c) => 'MmLlHhVvCcSsQqTtAaZz'.contains(c);

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

/// A forgiving cursor over path data, handling SVG's wsp/comma separators and
/// its delimiter-free number packing (`.5.5`, `1-2`, `1e2`).
class _Scanner {
  _Scanner(this.s);
  final String s;
  int i = 0;

  bool get atEnd => i >= s.length;

  void skipSep() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      // wsp (space, tab, LF, CR, FF) or comma
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x0C || c == 0x2C) {
        i++;
      } else {
        break;
      }
    }
  }

  /// Read a number; `null` (cursor restored) if none is present.
  double? num_() {
    skipSep();
    final start = i;
    if (i < s.length && (s[i] == '+' || s[i] == '-')) i++;
    var digits = false;
    while (i < s.length && _isDigit(s.codeUnitAt(i))) {
      i++;
      digits = true;
    }
    if (i < s.length && s[i] == '.') {
      i++;
      while (i < s.length && _isDigit(s.codeUnitAt(i))) {
        i++;
        digits = true;
      }
    }
    if (!digits) {
      i = start;
      return null;
    }
    if (i < s.length && (s[i] == 'e' || s[i] == 'E')) {
      final save = i;
      i++;
      if (i < s.length && (s[i] == '+' || s[i] == '-')) i++;
      var expDigits = false;
      while (i < s.length && _isDigit(s.codeUnitAt(i))) {
        i++;
        expDigits = true;
      }
      if (!expDigits) i = save; // bare 'e' — not part of the number
    }
    return double.tryParse(s.substring(start, i));
  }

  /// Arc flags are a single `0` or `1`, possibly packed against neighbours.
  int? flag() {
    skipSep();
    if (i < s.length && (s[i] == '0' || s[i] == '1')) {
      final v = s[i] == '1' ? 1 : 0;
      i++;
      return v;
    }
    return null;
  }
}
