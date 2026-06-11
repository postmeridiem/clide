import 'dart:io';

import 'package:flutter/widgets.dart';

/// A [FileImage] whose cache key also folds in the file's modification time and
/// size — so re-showing a path whose bytes changed *in place* re-decodes
/// instead of returning Flutter's stale cached frame (T-312).
///
/// Plain `Image.file` / `FileImage` key the global `imageCache` by `(path,
/// scale)` only, so overwriting a file at the same path is invisible: the cache
/// hands back the previously decoded image. Hit live when re-exporting a
/// wireframe PNG in place kept showing the prior render. Folding mtime + size
/// into `==`/`hashCode` makes an overwrite a fresh key → a cache miss → a
/// re-read of the current bytes; an unchanged file still hits the cache.
class ClideFileImage extends FileImage {
  ClideFileImage(String path, {double scale = 1.0}) : _stamp = _stampOf(path), super(File(path), scale: scale);

  /// mtime ⊕ size — changes on any in-place overwrite (a write bumps mtime; a
  /// different length bumps size even within one clock tick). 0 if the file
  /// can't be stat'd, which falls back to plain path+scale keying.
  final int _stamp;

  static int _stampOf(String path) {
    try {
      final s = File(path).statSync();
      return s.modified.millisecondsSinceEpoch ^ s.size;
    } catch (_) {
      return 0;
    }
  }

  @override
  bool operator ==(Object other) => other is ClideFileImage && other.file.path == file.path && other.scale == scale && other._stamp == _stamp;

  @override
  int get hashCode => Object.hash(file.path, scale, _stamp);
}
