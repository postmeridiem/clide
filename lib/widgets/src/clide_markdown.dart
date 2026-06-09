import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/src/clide_code_block.dart';
import 'package:clide/widgets/src/clide_divider.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;

typedef RecordTapCallback = void Function(String id);

/// Builds the inline widget for a recognised `@<path>` image token (T-236). The
/// caller owns how the image renders (thumbnail, tap-to-lightbox); the renderer
/// only locates the tokens and drops the widget into the text flow.
typedef ImageTokenBuilder = Widget Function(String path);

/// Invoked when a rendered http(s) link is activated (T-253) — the caller opens
/// it (e.g. the OS URL handler).
typedef LinkTapCallback = void Function(String url);

/// The interaction hooks a [ClideMarkdown] render may fire — bundled into one
/// value so the render tree threads a single object instead of a growing list
/// of optional callbacks. All optional; a null hook leaves that affordance
/// inert (the text renders, just not interactive).
@immutable
class ClideMarkdownHooks {
  const ClideMarkdownHooks({this.onRecordTap, this.onImageToken, this.onLinkTap});

  /// Tap a governance/ticket ref (T-281, D-77, …) → open the record (T-279).
  final RecordTapCallback? onRecordTap;

  /// Build the inline widget for a pasted-image `@<path>` token (T-236).
  final ImageTokenBuilder? onImageToken;

  /// Open an activated http(s) link (T-253).
  final LinkTapCallback? onLinkTap;

  static const none = ClideMarkdownHooks();
}

class ClideMarkdown extends StatelessWidget {
  const ClideMarkdown(this.source, {super.key, this.onRecordTap, this.onImageToken, this.onLinkTap});

  static const double _fontSize = 16;
  static const double _lineHeight = clideLineHeight;

  /// A whole string that is exactly a record id — used for record-shaped
  /// markdown links (`[T-281](…)`).
  static final _recordPattern = RegExp(r'^[DQRT]-\d+$');

  /// A bare governance/ticket ref inside running text (T-279): T-281, D-77,
  /// Q-5, R-2. Anchored on word boundaries so "T-shirt" (no digits) and
  /// "PT-281" (mid-word) stay literal. Only applied to rendered text — `code`
  /// spans and `pre` blocks render verbatim and never reach the linkifier, so
  /// refs inside code stay plain.
  static final _bareRecordPattern = RegExp(r'\b[DQRT]-\d+\b');

  /// A pasted-image `@<path>` token in running text (T-236): an `@` at a token
  /// boundary followed by a path ending in an image extension. The lookbehind
  /// keeps `foo@bar.png` (email-ish, mid-word) literal — only start-of-string or
  /// a preceding space qualifies, which is how the composer emits them.
  static final _imageTokenPattern = RegExp(r'(?<![^\s])@(\S+\.(?:png|jpe?g|gif|webp|bmp))', caseSensitive: false);

  final String source;
  final RecordTapCallback? onRecordTap;
  final ImageTokenBuilder? onImageToken;
  final LinkTapCallback? onLinkTap;

  static String _unescapeHtml(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final doc = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
    final nodes = doc.parseLines(source.split('\n'));
    final hooks = ClideMarkdownHooks(onRecordTap: onRecordTap, onImageToken: onImageToken, onLinkTap: onLinkTap);
    final widgets = _buildNodes(nodes, tokens, hooks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  static const _inlineTags = {'strong', 'em', 'code', 'a', 'del', 'br', 'img', 'span'};

  static bool _isInline(md.Node node) {
    if (node is md.Text) return true;
    if (node is md.Element) return _inlineTags.contains(node.tag);
    return false;
  }

  static List<Widget> _buildNodes(List<md.Node> nodes, SurfaceTokens tokens, ClideMarkdownHooks hooks) {
    final out = <Widget>[];
    final inlineRun = <md.Node>[];

    void flushInline() {
      if (inlineRun.isEmpty) return;
      final spans = <InlineSpan>[];
      for (final n in inlineRun) {
        if (n is md.Text) {
          spans.addAll(_linkifyText(_unescapeHtml(n.text), tokens, hooks));
        } else if (n is md.Element) {
          spans.add(_inlineElementSpan(n, tokens, hooks));
        }
      }
      out.add(Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: clideUiFamily,
            fontFamilyFallback: clideUiFamilyFallback,
            fontWeight: clideUiDefaultWeight,
            color: tokens.globalForeground,
            fontSize: _fontSize,
            height: _lineHeight,
          ),
          children: spans,
        ),
      ));
      inlineRun.clear();
    }

    for (final node in nodes) {
      if (_isInline(node)) {
        inlineRun.add(node);
      } else {
        flushInline();
        if (node is md.Element) {
          out.add(_buildElement(node, tokens, hooks));
        }
      }
    }
    flushInline();
    return out;
  }

  static Widget _buildElement(md.Element el, SurfaceTokens tokens, ClideMarkdownHooks hooks) {
    switch (el.tag) {
      case 'h1':
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: _inlineText(el, tokens, hooks, fontSize: 22, fontWeight: FontWeight.w500),
        );
      case 'h2':
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 10),
          child: _inlineText(el, tokens, hooks, fontSize: 18, fontWeight: FontWeight.w500),
        );
      case 'h3':
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: _inlineText(el, tokens, hooks, fontSize: 16, fontWeight: FontWeight.w500),
        );
      case 'h4':
      case 'h5':
      case 'h6':
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: _inlineText(el, tokens, hooks, fontSize: clideFontBody, fontWeight: FontWeight.w600),
        );
      case 'p':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _inlineRichText(el, tokens, hooks),
        );
      case 'ul':
        return Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in el.children ?? const [])
                if (c is md.Element) _buildListItem(c, tokens, hooks, ordered: false)
            ],
          ),
        );
      case 'ol':
        return Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < (el.children?.length ?? 0); i++)
                if (el.children![i] is md.Element) _buildListItem(el.children![i] as md.Element, tokens, hooks, ordered: true, index: i + 1),
            ],
          ),
        );
      case 'blockquote':
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: tokens.globalTextMuted, width: 3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: _buildNodes(el.children?.cast<md.Node>() ?? const [], tokens, hooks),
          ),
        );
      case 'pre':
        final codeEl = el.children?.whereType<md.Element>().firstOrNull;
        final code = _unescapeHtml(codeEl?.textContent ?? el.textContent);
        String? lang;
        final cls = codeEl?.attributes['class'];
        if (cls != null && cls.startsWith('language-')) {
          lang = cls.substring(9);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClideCodeBlock(source: code, language: lang),
        );
      case 'hr':
        return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: ClideDivider());
      case 'table':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildTable(el, tokens, hooks),
        );
      default:
        return _inlineRichText(el, tokens, hooks);
    }
  }

  static Widget _buildListItem(md.Element el, SurfaceTokens tokens, ClideMarkdownHooks hooks, {bool ordered = false, int index = 1}) {
    final bullet = ordered ? '$index. ' : '• ';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClideText(bullet, color: tokens.globalTextMuted, fontSize: _fontSize),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: _buildNodes(el.children?.cast<md.Node>() ?? const [], tokens, hooks),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTable(md.Element table, SurfaceTokens tokens, ClideMarkdownHooks hooks) {
    final rows = <TableRow>[];
    for (final child in table.children ?? const []) {
      if (child is! md.Element) continue;
      for (final row in child.children ?? const []) {
        if (row is! md.Element) continue;
        final cells = <Widget>[];
        final isHeader = row.tag == 'tr' && (child.tag == 'thead');
        for (final cell in row.children ?? const []) {
          if (cell is! md.Element) continue;
          cells.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: _inlineText(cell, tokens, hooks, fontWeight: isHeader ? FontWeight.w600 : null),
          ));
        }
        if (cells.isNotEmpty) {
          rows.add(TableRow(
            decoration: isHeader ? BoxDecoration(border: Border(bottom: BorderSide(color: tokens.dividerColor))) : null,
            children: cells,
          ));
        }
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Table(
      border: TableBorder.all(color: tokens.panelBorder, width: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: rows,
    );
  }

  static Widget _inlineText(md.Element el, SurfaceTokens tokens, ClideMarkdownHooks hooks, {double? fontSize, FontWeight? fontWeight}) {
    return Text.rich(_buildInlineSpan(el, tokens, hooks, fontSize: fontSize, fontWeight: fontWeight));
  }

  static Widget _inlineRichText(md.Element el, SurfaceTokens tokens, ClideMarkdownHooks hooks) {
    return Text.rich(_buildInlineSpan(el, tokens, hooks));
  }

  static TextSpan _buildInlineSpan(md.Element el, SurfaceTokens tokens, ClideMarkdownHooks hooks, {double? fontSize, FontWeight? fontWeight}) {
    final children = <InlineSpan>[];
    for (final child in el.children ?? const []) {
      if (child is md.Text) {
        children.addAll(_linkifyText(_unescapeHtml(child.text), tokens, hooks));
      } else if (child is md.Element) {
        children.add(_inlineElementSpan(child, tokens, hooks));
      }
    }
    return TextSpan(
      style: TextStyle(
        fontFamily: clideUiFamily,
        fontFamilyFallback: clideUiFamilyFallback,
        fontWeight: fontWeight ?? clideUiDefaultWeight,
        color: tokens.globalForeground,
        fontSize: fontSize ?? _fontSize,
        height: _lineHeight,
      ),
      children: children,
    );
  }

  static InlineSpan _inlineElementSpan(md.Element el, SurfaceTokens tokens, ClideMarkdownHooks hooks) {
    switch (el.tag) {
      case 'strong':
        return TextSpan(
          style: const TextStyle(fontWeight: FontWeight.w700),
          children: [
            for (final c in el.children ?? const [])
              if (c is md.Text) ..._linkifyText(_unescapeHtml(c.text), tokens, hooks) else if (c is md.Element) _inlineElementSpan(c, tokens, hooks)
          ],
        );
      case 'em':
        return TextSpan(
          style: const TextStyle(fontStyle: FontStyle.italic),
          children: [
            for (final c in el.children ?? const [])
              if (c is md.Text) ..._linkifyText(_unescapeHtml(c.text), tokens, hooks) else if (c is md.Element) _inlineElementSpan(c, tokens, hooks)
          ],
        );
      case 'code':
        return TextSpan(
          text: _unescapeHtml(el.textContent),
          style: TextStyle(fontFamily: clideMonoFamily, fontSize: clideFontMono, color: tokens.syntaxString, backgroundColor: tokens.panelBackground),
        );
      case 'a':
        final text = _unescapeHtml(el.textContent);
        if (hooks.onRecordTap != null && _recordPattern.hasMatch(text)) {
          return _recordLinkSpan(text, tokens, hooks.onRecordTap!);
        }
        // An http(s) link (explicit or autolinked) → tappable, opens via the
        // caller's handler (T-253). Non-http schemes stay coloured-but-inert.
        final href = el.attributes['href'];
        if (hooks.onLinkTap != null && href != null && _isHttpUrl(href)) {
          return _urlLinkSpan(text, href, tokens, hooks.onLinkTap!);
        }
        return TextSpan(
          text: text,
          style: TextStyle(color: tokens.globalFocus),
        );
      case 'del':
        return TextSpan(
          text: _unescapeHtml(el.textContent),
          style: TextStyle(decoration: TextDecoration.lineThrough, color: tokens.globalTextMuted),
        );
      default:
        return TextSpan(text: _unescapeHtml(el.textContent));
    }
  }

  /// Splits plain [text] into spans: pasted-image `@<path>` tokens become inline
  /// image widgets via [onImageToken] (T-236), and bare governance/ticket refs
  /// (T-281, D-77, Q-5, R-2) become clickable [_recordLinkSpan]s (T-279). With
  /// neither callback (or no match) the text passes through unchanged.
  static List<InlineSpan> _linkifyText(String text, SurfaceTokens tokens, ClideMarkdownHooks hooks) {
    if (text.isEmpty) return [TextSpan(text: text)];
    // Pass 1: pull out image tokens, record-linkifying the prose between them.
    if (hooks.onImageToken != null) {
      final spans = <InlineSpan>[];
      var last = 0;
      for (final m in _imageTokenPattern.allMatches(text)) {
        if (m.start > last) spans.addAll(_linkifyRecords(text.substring(last, m.start), tokens, hooks.onRecordTap));
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: hooks.onImageToken!(m.group(1)!)),
        ));
        last = m.end;
      }
      if (last < text.length) spans.addAll(_linkifyRecords(text.substring(last), tokens, hooks.onRecordTap));
      return spans.isEmpty ? [TextSpan(text: text)] : spans;
    }
    return _linkifyRecords(text, tokens, hooks.onRecordTap);
  }

  static List<InlineSpan> _linkifyRecords(String text, SurfaceTokens tokens, RecordTapCallback? onRecordTap) {
    if (onRecordTap == null || text.isEmpty) return [TextSpan(text: text)];
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _bareRecordPattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(_recordLinkSpan(m[0]!, tokens, onRecordTap));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans.isEmpty ? [TextSpan(text: text)] : spans;
  }

  /// A clickable record-reference span: [id] rendered in the focus accent with
  /// a hover underline, firing [onRecordTap] on tap (T-279). Shared by bare-text
  /// refs and record-shaped markdown links so both look and behave alike.
  static InlineSpan _recordLinkSpan(String id, SurfaceTokens tokens, RecordTapCallback onRecordTap) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: ClideTappable(
        onTap: () => onRecordTap(id),
        builder: (_, hovered, __) => Text(
          id,
          style: TextStyle(
            color: tokens.globalFocus,
            fontSize: _fontSize,
            height: _lineHeight,
            fontFamily: clideMonoFamily,
            decoration: hovered ? TextDecoration.underline : null,
            decorationColor: tokens.globalFocus,
          ),
        ),
      ),
    );
  }

  static bool _isHttpUrl(String s) {
    final u = Uri.tryParse(s);
    return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
  }

  /// A clickable http(s) link span (T-253): the link [text] in the focus accent,
  /// underlined on hover, opening [href] via [onLinkTap]. Keyboard-activatable
  /// (ClideTappable) and tooltipped with the destination.
  static InlineSpan _urlLinkSpan(String text, String href, SurfaceTokens tokens, LinkTapCallback onLinkTap) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: ClideTappable(
        onTap: () => onLinkTap(href),
        tooltip: href,
        builder: (_, hovered, __) => Text(
          text,
          style: TextStyle(
            color: tokens.globalFocus,
            fontSize: _fontSize,
            height: _lineHeight,
            fontFamily: clideUiFamily,
            fontFamilyFallback: clideUiFamilyFallback,
            decoration: hovered ? TextDecoration.underline : null,
            decorationColor: tokens.globalFocus,
          ),
        ),
      ),
    );
  }
}
