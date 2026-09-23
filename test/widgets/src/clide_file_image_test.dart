/// [ClideFileImage] folds mtime + size into the imageCache key so an in-place
/// overwrite re-decodes instead of returning Flutter's stale frame (T-312).
library;

import 'dart:io';

import 'package:clide/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an in-place overwrite produces a different cache key', () {
    final dir = Directory.systemTemp.createTempSync('clide_fileimg_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/img.bin')..writeAsBytesSync([1, 2, 3]);

    final before = ClideFileImage(f.path);
    // Same bytes → same key (cache hit).
    expect(before, ClideFileImage(f.path));
    expect(before.hashCode, ClideFileImage(f.path).hashCode);

    // Overwrite at the same path with a different length → different key.
    f.writeAsBytesSync([9, 8, 7, 6]);
    final after = ClideFileImage(f.path);
    expect(after, isNot(before));
    expect(after.hashCode, isNot(before.hashCode));
    expect(after.file.path, before.file.path); // same path, just a fresh key
  });

  // The key was mtime XOR size, which collides whenever size1 ^ size2 ==
  // mtime1 ^ mtime2 — e.g. 3 bytes at an mtime ending in binary 011, then 4
  // bytes one millisecond later: the quick in-place overwrite this exists for,
  // seen as a flake. setLastModified keeps whole seconds only, so the test
  // picks the second size to collide with a one-second step instead.
  test('an overwrite whose size and mtime change together is never a cache hit', () {
    final dir = Directory.systemTemp.createTempSync('clide_fileimg_');
    addTearDown(() => dir.deleteSync(recursive: true));
    const m1 = 1700000000000, m2 = 1700000001000;
    const size1 = 1;
    const size2 = size1 ^ m1 ^ m2; // makes m1 ^ size1 == m2 ^ size2
    final f = File('${dir.path}/img.bin')..writeAsBytesSync(List.filled(size1, 0));
    f.setLastModifiedSync(DateTime.fromMillisecondsSinceEpoch(m1));
    final before = ClideFileImage(f.path);

    f.writeAsBytesSync(List.filled(size2, 0));
    f.setLastModifiedSync(DateTime.fromMillisecondsSinceEpoch(m2));
    expect(ClideFileImage(f.path), isNot(before));
  });

  test('a missing file falls back to path-only keying', () {
    expect(ClideFileImage('/no/such/clide/file.png'), ClideFileImage('/no/such/clide/file.png'));
  });
}
