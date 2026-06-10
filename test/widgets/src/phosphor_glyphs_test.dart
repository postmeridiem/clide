/// Guards the Phosphor label→codepoint indirection (T-314). The named consts
/// are gone; code resolves glyphs by string via [PhosphorIcons.byName]. A
/// string key loses the compiler's typo check, so this test recovers it: every
/// `byName('…')` string literal in `lib/` must exist in the generated map —
/// across all call sites, executed or not.
library;

import 'dart:io';

import 'package:clide/widgets/src/icons/phosphor_glyphs.g.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the generated glyph map covers the full Phosphor set', () {
    expect(kPhosphorGlyphs.length, greaterThanOrEqualTo(1500));
    expect(kPhosphorGlyphs.containsKey('folder'), isTrue);
    // The fallback glyph must itself resolve, or byName would throw on a miss.
    expect(kPhosphorGlyphs.containsKey(PhosphorIcons.fallbackName), isTrue);
  });

  test('every byName(\'…\') literal in lib/ resolves to a real glyph', () {
    final call = RegExp(r"byName\(\s*'([a-z0-9-]+)'\s*\)");
    final missing = <String, String>{}; // label -> first file it appears in
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final m in call.allMatches(entity.readAsStringSync())) {
        final label = m.group(1)!;
        if (!kPhosphorGlyphs.containsKey(label)) {
          missing.putIfAbsent(label, () => entity.path);
        }
      }
    }
    expect(missing, isEmpty, reason: 'unknown Phosphor glyph name(s) in byName(): $missing');
  });

  test('byName resolves a known name to its codepoint', () {
    expect(PhosphorIcons.byName('folder').codePoint, kPhosphorGlyphs['folder']);
    expect(PhosphorIcons.byName('caret-line-left').codePoint, kPhosphorGlyphs['caret-line-left']);
  });

  test('byName degrades an unknown name to the placeholder fallback (never throws)', () {
    final fallback = kPhosphorGlyphs[PhosphorIcons.fallbackName];
    expect(PhosphorIcons.byName('definitely-not-a-real-glyph').codePoint, fallback);
    expect(PhosphorIcons.fallbackName, 'placeholder');
  });
}
