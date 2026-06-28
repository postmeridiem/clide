import 'dart:io';

import 'package:clide/src/svg/svg_document.dart';
import 'package:clide/src/svg/svg_node.dart';
import 'package:test/test.dart';

/// End-to-end: the full raw-SVG → typed-scene pipeline against a real diagram
/// rendered by the `d2` binary (the output we sampled while scoping T-320).
void main() {
  Iterable<SvgNode> flatten(SvgNode n) sync* {
    yield n;
    if (n is SvgGroup) {
      for (final c in n.children) {
        yield* flatten(c);
      }
    }
  }

  test('builds a real d2-rendered SVG into a sane scene', () {
    final svg = File('test/svg/fixtures/d2_pipeline.svg').readAsStringSync();
    final doc = buildSvgDocument(svg);
    final nodes = flatten(doc.root).toList();

    expect(doc.viewBox, isNotNull, reason: 'd2 sets a viewBox');

    // The four pipeline labels render as <text>.
    final labels = nodes.whereType<SvgText>().map((t) => t.text).toSet();
    expect(labels, containsAll(['fetch', 'build', 'test', 'deploy']));

    // The node boxes render as <rect>.
    expect(nodes.whereType<SvgRect>(), isNotEmpty);

    // The edges render as <path>, and their class-driven fill resolved to ARGB
    // (proves the <style> → inline normalize → colour pipeline end to end).
    final paths = nodes.whereType<SvgPath>().toList();
    expect(paths.length, greaterThanOrEqualTo(3));
    expect(paths.where((p) => p.style.fill != null), isNotEmpty);
  });
}
