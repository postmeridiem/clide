/// SVG / CSS colour parsing for the renderer (T-320 / D-103).
///
/// Converts an SVG colour string into a packed `0xAARRGGBB` int the painter can
/// hand to a `dart:ui` Color. Handles `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`,
/// `rgb()/rgba()` (integer or percentage channels), the common named colours,
/// and `none`/`transparent` (→ fully transparent, so the painter simply skips
/// it). Returns `null` for anything unrecognised so the caller can fall back to
/// the inherited / default paint. Never throws.
///
/// A colour is CONTENT, not a clide theme token (D-103 / D-7): an SVG fill is
/// whatever the document says, independent of clide's palette.
///
/// Flutter-free: pure Dart, runs under `dart test`.
library;

/// Parse an SVG colour to packed ARGB (`0xAARRGGBB`); `null` if unrecognised.
/// `none` / `transparent` → `0x00000000`.
int? parseSvgColor(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  if (s == 'none' || s == 'transparent') return 0x00000000;
  if (s.startsWith('#')) return _hex(s.substring(1));
  if (s.startsWith('rgb')) return _rgb(s);
  return _named[s];
}

int? _hex(String h) {
  String dbl(String c) => '$c$c';
  String rr, gg, bb, aa;
  switch (h.length) {
    case 3:
      rr = dbl(h[0]);
      gg = dbl(h[1]);
      bb = dbl(h[2]);
      aa = 'ff';
    case 4:
      rr = dbl(h[0]);
      gg = dbl(h[1]);
      bb = dbl(h[2]);
      aa = dbl(h[3]);
    case 6:
      rr = h.substring(0, 2);
      gg = h.substring(2, 4);
      bb = h.substring(4, 6);
      aa = 'ff';
    case 8:
      rr = h.substring(0, 2);
      gg = h.substring(2, 4);
      bb = h.substring(4, 6);
      aa = h.substring(6, 8);
    default:
      return null;
  }
  final r = int.tryParse(rr, radix: 16);
  final g = int.tryParse(gg, radix: 16);
  final b = int.tryParse(bb, radix: 16);
  final a = int.tryParse(aa, radix: 16);
  if (r == null || g == null || b == null || a == null) return null;
  return (a << 24) | (r << 16) | (g << 8) | b;
}

int? _rgb(String s) {
  final open = s.indexOf('('), close = s.indexOf(')');
  if (open < 0 || close < open) return null;
  final parts = s.substring(open + 1, close).split(',').map((p) => p.trim()).toList();
  if (parts.length < 3) return null;

  int chan(String p) {
    if (p.endsWith('%')) {
      final pct = double.tryParse(p.substring(0, p.length - 1)) ?? 0;
      return (pct / 100 * 255).round().clamp(0, 255);
    }
    return (double.tryParse(p) ?? 0).round().clamp(0, 255);
  }

  final r = chan(parts[0]), g = chan(parts[1]), b = chan(parts[2]);
  var a = 255;
  if (parts.length >= 4) {
    final af = double.tryParse(parts[3]);
    if (af != null) a = (af * 255).round().clamp(0, 255);
  }
  return (a << 24) | (r << 16) | (g << 8) | b;
}

/// Common named colours (the CSS basics plus a few greys d2/graphviz emit).
/// Extended names can be added as needed — d2 uses hex, so this is mostly for
/// hand-authored SVG.
const Map<String, int> _named = {
  'black': 0xFF000000,
  'white': 0xFFFFFFFF,
  'red': 0xFFFF0000,
  'lime': 0xFF00FF00,
  'green': 0xFF008000,
  'blue': 0xFF0000FF,
  'yellow': 0xFFFFFF00,
  'cyan': 0xFF00FFFF,
  'aqua': 0xFF00FFFF,
  'magenta': 0xFFFF00FF,
  'fuchsia': 0xFFFF00FF,
  'silver': 0xFFC0C0C0,
  'gray': 0xFF808080,
  'grey': 0xFF808080,
  'maroon': 0xFF800000,
  'olive': 0xFF808000,
  'teal': 0xFF008080,
  'navy': 0xFF000080,
  'purple': 0xFF800080,
  'orange': 0xFFFFA500,
  'pink': 0xFFFFC0CB,
  'brown': 0xFFA52A2A,
  'gold': 0xFFFFD700,
  'lightgray': 0xFFD3D3D3,
  'lightgrey': 0xFFD3D3D3,
  'darkgray': 0xFFA9A9A9,
  'darkgrey': 0xFFA9A9A9,
  'whitesmoke': 0xFFF5F5F5,
};
