// Based on xterm.dart v4.0.0 by xuty (MIT). See LICENSE in this directory.

import 'dart:collection';
import 'dart:ui';

import 'package:flutter/widgets.dart';

class _LruCache<K, V> {
  _LruCache(this._maxSize);
  final int _maxSize;
  final _map = LinkedHashMap<K, V>();

  V? operator [](K key) {
    final value = _map.remove(key);
    if (value != null) _map[key] = value;
    return value;
  }

  void operator []=(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    while (_map.length > _maxSize) {
      _map.remove(_map.keys.first);
    }
  }

  void clear() => _map.clear();
  int get length => _map.length;
}

class ParagraphCache {
  ParagraphCache(int maximumSize) : _cache = _LruCache<int, Paragraph>(maximumSize);

  final _LruCache<int, Paragraph> _cache;

  Paragraph? getLayoutFromCache(int key) => _cache[key];

  Paragraph performAndCacheLayout(
    String text,
    TextStyle style,
    TextScaler textScaler,
    int key,
  ) {
    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.pushStyle(style.getTextStyle(textScaler: textScaler));
    builder.addText(text);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    _cache[key] = paragraph;
    return paragraph;
  }

  void clear() => _cache.clear();

  int get length => _cache.length;
}
