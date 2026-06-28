/// Inline-style normalizer for the SVG renderer (T-320 / D-103).
///
/// d2 / graphviz style their output with a `<style>` block of flat single-class
/// selectors (`.fill-B1`, `.shape`, `.connection`, `.text-bold`) plus `class=`
/// references, not inline presentation attributes. Rather than teach the painter
/// CSS, [inlineStyles] runs ONCE up front: it parses the `<style>` rules, folds
/// each element's matching tag/class declarations (and any `style=""`) into
/// explicit presentation attributes, then drops the `<style>` elements and the
/// `class`/`style` attributes. Downstream the painter only ever sees inline
/// attributes — a pure presentation-attribute renderer (D-103).
///
/// Cascade (low → high precedence), per the SVG/CSS model: presentation
/// attributes < tag rule < class rules (document order) < `style=""`. Only the
/// **simple** selectors d2/graphviz emit are honoured (a bare tag or a single
/// `.class`); compound/descendant selectors are ignored. Geometry attributes
/// (`x`, `d`, `transform`, `href`, …) are never touched.
///
/// Flutter-free: pure Dart, runs under `dart test`.
library;

import 'svg_xml.dart';

/// Presentation properties the renderer cares about — the only attributes read
/// as the lowest cascade layer (so geometry attributes stay untouched).
const Set<String> presentationProps = {
  'fill',
  'fill-opacity',
  'fill-rule',
  'stroke',
  'stroke-width',
  'stroke-opacity',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-dasharray',
  'stroke-dashoffset',
  'opacity',
  'color',
  'font-family',
  'font-size',
  'font-weight',
  'font-style',
  'text-anchor',
  'dominant-baseline',
  'alignment-baseline',
  'visibility',
  'display',
};

/// Flatten `<style>`/`class`/`style=` into inline presentation attributes,
/// in place. After this, the tree has no `<style>` elements and no `class`/
/// `style` attributes — every style is an explicit presentation attribute.
void inlineStyles(XmlElement root) {
  final rules = <String, Map<String, String>>{};
  _collectStyleRules(root, rules);
  _removeStyleElements(root);
  _fold(root, rules);
}

void _collectStyleRules(XmlElement el, Map<String, Map<String, String>> into) {
  if (el.name == 'style') {
    final css = el.children.whereType<XmlText>().map((t) => t.text).join('\n');
    parseCss(css).forEach((sel, decls) => (into[sel] ??= <String, String>{}).addAll(decls));
  }
  for (final c in el.children) {
    if (c is XmlElement) _collectStyleRules(c, into);
  }
}

void _removeStyleElements(XmlElement el) {
  el.children.removeWhere((c) => c is XmlElement && c.name == 'style');
  for (final c in el.children) {
    if (c is XmlElement) _removeStyleElements(c);
  }
}

void _fold(XmlElement el, Map<String, Map<String, String>> rules) {
  final eff = <String, String>{};

  // 1. existing presentation attributes (lowest precedence)
  for (final p in presentationProps) {
    final v = el.attrs[p];
    if (v != null) eff[p] = v;
  }
  // 2. tag rule
  final tagRule = rules[el.name];
  if (tagRule != null) eff.addAll(tagRule);
  // 3. class rules, in the order classes are listed on the element
  final cls = el.attrs['class'];
  if (cls != null) {
    for (final c in cls.split(RegExp(r'\s+'))) {
      if (c.isEmpty) continue;
      final r = rules['.$c'];
      if (r != null) eff.addAll(r);
    }
  }
  // 4. inline style="" (highest precedence)
  final style = el.attrs['style'];
  if (style != null) eff.addAll(parseDecls(style));

  el.attrs
    ..remove('class')
    ..remove('style');
  eff.forEach((k, v) => el.attrs[k] = v);

  for (final c in el.children) {
    if (c is XmlElement) _fold(c, rules);
  }
}

/// Parse a CSS text block into `selector → { prop: value }`, keeping only the
/// simple selectors d2/graphviz emit (a bare tag or a single `.class`). Keys
/// are the raw selector (`.fill-B1` or `text`).
Map<String, Map<String, String>> parseCss(String css) {
  final out = <String, Map<String, String>>{};
  final cleaned = css.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ''); // strip comments
  for (final m in RegExp(r'([^{}]+)\{([^{}]*)\}').allMatches(cleaned)) {
    final decls = parseDecls(m.group(2)!);
    if (decls.isEmpty) continue;
    for (final raw in m.group(1)!.split(',')) {
      final sel = raw.trim();
      if (_isSimpleSelector(sel)) {
        (out[sel] ??= <String, String>{}).addAll(decls);
      }
    }
  }
  return out;
}

/// Parse `prop: value; prop: value` into a map (lower-cased property names).
Map<String, String> parseDecls(String decls) {
  final out = <String, String>{};
  for (final decl in decls.split(';')) {
    final c = decl.indexOf(':');
    if (c < 0) continue;
    final k = decl.substring(0, c).trim().toLowerCase();
    final v = decl.substring(c + 1).trim();
    if (k.isNotEmpty && v.isNotEmpty) out[k] = v;
  }
  return out;
}

/// A bare tag (`text`) or a single class (`.fill-B1`) — no combinators,
/// compounds, ids, or attribute selectors.
bool _isSimpleSelector(String s) => RegExp(r'^\.?[A-Za-z][\w-]*$').hasMatch(s);
