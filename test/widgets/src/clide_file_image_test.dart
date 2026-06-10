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

  test('a missing file falls back to path-only keying', () {
    expect(ClideFileImage('/no/such/clide/file.png'), ClideFileImage('/no/such/clide/file.png'));
  });
}
