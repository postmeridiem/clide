import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class Palette {
  const Palette(this._colors);
  final Map<String, Color> _colors;

  Color? lookup(String name) => _colors[name];
  Iterable<String> get names => _colors.keys;

  static Color? parseHex(String s) {
    var v = s.trim();
    if (v.startsWith('#')) v = v.substring(1);
    if (v.length == 6) v = 'FF$v';
    if (v.length != 8) return null;
    final n = int.tryParse(v, radix: 16);
    if (n == null) return null;
    return Color(n);
  }
}
