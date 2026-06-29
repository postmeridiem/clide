import 'package:clide/src/draw/compare_template.dart';
import 'package:clide/src/draw/draw_dispatch.dart';
import 'package:clide/src/draw/draw_doc.dart';
import 'package:test/test.dart';

void main() {
  DrawingCardDoc doc(List<Object?> images) => DrawingCardDoc(template: 'compare', fields: {'template': 'compare', 'images': images});

  // Resolver: prefix with /abs; null for a path named "missing.png".
  final handler = compareTemplateHandler(resolvePath: (p) => p == 'missing.png' ? null : '/abs/$p');

  test('lays out N image cells with hrefs, captions, and lightbox', () async {
    final r = await handler(
      doc([
        {'path': 'before.png', 'label': 'Before', 'description': 'cramped'},
        {'path': 'after.png', 'label': 'After'},
      ]),
    );
    final svg = (r as DrawOk).svg;
    expect(svg, contains('href="/abs/before.png"'));
    expect(svg, contains('href="/abs/after.png"'));
    expect(svg, contains('data-label="Before"'));
    expect(svg, contains('data-description="cramped"'));
    expect(svg, contains('data-lightbox=""'));
    expect(svg, contains('x="340"')); // second cell offset by 320 + 20 gap
    expect(svg, contains('viewBox="0 0 660 296"')); // 2*320+20 wide, 240+56 tall
  });

  test('an unresolved path is an honest error', () async {
    final r = await handler(
      doc([
        {'path': 'missing.png'},
      ]),
    );
    expect((r as DrawErr).message, contains('no such image'));
  });

  test('empty or missing images is an honest error', () async {
    expect(await handler(doc(const [])), isA<DrawErr>());
    expect(await handler(DrawingCardDoc(template: 'compare', fields: const {'template': 'compare'})), isA<DrawErr>());
  });

  test('a non-object entry is an honest error', () async {
    expect(await handler(doc(const ['notanobject'])), isA<DrawErr>());
  });

  test('escapes special characters in paths and labels', () async {
    final h = compareTemplateHandler(resolvePath: (p) => '/abs/$p');
    final r = await h(
      doc([
        {'path': 'a&b.png', 'label': '<x>'},
      ]),
    );
    final svg = (r as DrawOk).svg;
    expect(svg, contains('a&amp;b.png'));
    expect(svg, contains('data-label="&lt;x&gt;"'));
  });
}
