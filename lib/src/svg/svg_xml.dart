/// A minimal, tolerant XML reader for the SVG renderer (T-320 / D-103).
///
/// SVG is XML; rather than take a dependency (prefer-zero-deps), we parse the
/// bounded shape that d2 / graphviz / hand-authored SVG emit into a generic
/// element tree. NOT a conformant XML processor — it understands elements,
/// attributes, text, comments, the XML/DOCTYPE prolog, CDATA, and the common
/// entities; it deliberately reads `<style>`/`<script>` bodies as raw text
/// (their CSS/JS is not markup). Namespaced names (`xlink:href`) are kept
/// verbatim — we don't resolve namespaces.
///
/// Tolerant by construction: malformed input yields the tree understood so far
/// (or `null` for a non-element root) and never throws — a broken document must
/// not crash the conversation. Mismatched close tags are accepted.
///
/// Flutter-free: pure Dart, runs under `dart test`.
library;

/// A node in the parsed tree — either an [XmlElement] or [XmlText].
sealed class XmlNode {}

/// An element: a tag [name], its [attrs], and ordered [children].
/// Mutable so the style normalizer can fold classes into [attrs] in place.
class XmlElement extends XmlNode {
  XmlElement(this.name, this.attrs, this.children);
  final String name;
  final Map<String, String> attrs;
  final List<XmlNode> children;

  /// Depth-first descendants (excluding `this`), elements and text alike.
  Iterable<XmlNode> descendants() sync* {
    for (final c in children) {
      yield c;
      if (c is XmlElement) yield* c.descendants();
    }
  }

  @override
  String toString() => '<$name ${attrs.length} attrs, ${children.length} children>';
}

/// A run of text content (e.g. inside `<text>`, or a `<style>` body).
class XmlText extends XmlNode {
  XmlText(this.text);
  final String text;
  @override
  String toString() => 'text(${text.length})';
}

/// Parse [src] into its root [XmlElement], or `null` if there is no element
/// root. Never throws.
XmlElement? parseXml(String src) => _XmlParser(src).parseDocument();

class _XmlParser {
  _XmlParser(this.s);
  final String s;
  int i = 0;

  XmlElement? parseDocument() {
    _skipProlog();
    if (i >= s.length || s[i] != '<') return null;
    return _parseElement();
  }

  void _skipProlog() {
    while (i < s.length) {
      _skipWs();
      if (_at('<?')) {
        _skipPast('?>');
      } else if (_at('<!--')) {
        _skipPast('-->');
      } else if (_at('<!')) {
        // DOCTYPE or other declaration
        _skipPast('>');
      } else {
        break;
      }
    }
  }

  XmlElement? _parseElement() {
    if (i >= s.length || s[i] != '<') return null;
    i++; // '<'
    final name = _readName();
    if (name.isEmpty) return null;
    final attrs = <String, String>{};

    // Attributes up to '>' or '/>'.
    while (i < s.length) {
      _skipWs();
      if (i >= s.length) return XmlElement(name, attrs, const []);
      final c = s[i];
      if (c == '/') {
        i++;
        if (i < s.length && s[i] == '>') i++;
        return XmlElement(name, attrs, []); // self-closing
      }
      if (c == '>') {
        i++;
        break;
      }
      final an = _readName();
      if (an.isEmpty) {
        i++; // skip a stray char rather than spin
        continue;
      }
      _skipWs();
      if (i < s.length && s[i] == '=') {
        i++;
        _skipWs();
        attrs[an] = _readAttrValue();
      } else {
        attrs[an] = '';
      }
    }

    // Raw-text elements: their body is not markup.
    if (name == 'style' || name == 'script') {
      final raw = _readRawUntilClose(name);
      return XmlElement(name, attrs, raw.isEmpty ? [] : [XmlText(raw)]);
    }

    final children = <XmlNode>[];
    while (i < s.length) {
      if (_at('</')) {
        i += 2;
        _readName(); // tolerate a mismatched close name
        _skipWs();
        if (i < s.length && s[i] == '>') i++;
        break;
      } else if (_at('<!--')) {
        _skipPast('-->');
      } else if (_at('<![CDATA[')) {
        i += 9;
        final end = s.indexOf(']]>', i);
        children.add(XmlText(end < 0 ? s.substring(i) : s.substring(i, end)));
        i = end < 0 ? s.length : end + 3;
      } else if (s[i] == '<') {
        final child = _parseElement();
        if (child == null) break;
        children.add(child);
      } else {
        final start = i;
        while (i < s.length && s[i] != '<') {
          i++;
        }
        final text = _decodeEntities(s.substring(start, i));
        if (text.trim().isNotEmpty) children.add(XmlText(text));
      }
    }
    return XmlElement(name, attrs, children);
  }

  String _readName() {
    final start = i;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      final isNameChar =
          (c >= 0x41 && c <= 0x5A) || // A-Z
          (c >= 0x61 && c <= 0x7A) || // a-z
          (c >= 0x30 && c <= 0x39) || // 0-9
          c == 0x2D || // -
          c == 0x5F || // _
          c == 0x2E || // .
          c == 0x3A; // : (namespaced)
      if (!isNameChar) break;
      i++;
    }
    return s.substring(start, i);
  }

  String _readAttrValue() {
    if (i >= s.length) return '';
    final q = s[i];
    if (q == '"' || q == "'") {
      i++;
      final start = i;
      while (i < s.length && s[i] != q) {
        i++;
      }
      final v = s.substring(start, i);
      if (i < s.length) i++; // closing quote
      return _decodeEntities(v);
    }
    // Unquoted value (not valid XML, but be tolerant).
    final start = i;
    while (i < s.length && s[i] != ' ' && s[i] != '>' && s[i] != '/') {
      i++;
    }
    return _decodeEntities(s.substring(start, i));
  }

  String _readRawUntilClose(String tag) {
    final close = '</$tag';
    final idx = s.indexOf(close, i);
    if (idx < 0) {
      final rest = s.substring(i);
      i = s.length;
      return rest;
    }
    final body = s.substring(i, idx);
    i = idx + close.length;
    _skipPast('>');
    return body;
  }

  void _skipWs() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        i++;
      } else {
        break;
      }
    }
  }

  bool _at(String tok) => s.startsWith(tok, i);

  void _skipPast(String tok) {
    final idx = s.indexOf(tok, i);
    i = idx < 0 ? s.length : idx + tok.length;
  }
}

/// Decode the handful of XML entities SVG actually uses.
String _decodeEntities(String s) {
  if (!s.contains('&')) return s;
  return s.replaceAllMapped(RegExp(r'&(#x?[0-9A-Fa-f]+|amp|lt|gt|quot|apos);'), (m) {
    final e = m.group(1)!;
    switch (e) {
      case 'amp':
        return '&';
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'quot':
        return '"';
      case 'apos':
        return "'";
      default:
        final hex = e.startsWith('#x') || e.startsWith('#X');
        final digits = e.substring(hex ? 2 : 1);
        final code = int.tryParse(digits, radix: hex ? 16 : 10);
        return code == null ? m.group(0)! : String.fromCharCode(code);
    }
  });
}
