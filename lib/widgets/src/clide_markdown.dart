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

class ClideMarkdown extends StatelessWidget {
  const ClideMarkdown(this.source, {super.key, this.onRecordTap});

  static const double _fontSize = 16;
  static const double _lineHeight = clideLineHeight;
  static final _recordPattern = RegExp(r'^[DQRT]-\d+$');

  final String source;
  final RecordTapCallback? onRecordTap;

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
    final widgets = _buildNodes(nodes, tokens, onRecordTap);
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

  static List<Widget> _buildNodes(List<md.Node> nodes, SurfaceTokens tokens, RecordTapCallback? onRecordTap) {
    final out = <Widget>[];
    final inlineRun = <md.Node>[];

    void flushInline() {
      if (inlineRun.isEmpty) return;
      final spans = <InlineSpan>[];
      for (final n in inlineRun) {
        if (n is md.Text) {
          spans.add(TextSpan(text: _unescapeHtml(n.text)));
        } else if (n is md.Element) {
          spans.add(_inlineElementSpan(n, tokens, onRecordTap));
        }
      }
      out.add(RichText(
        text: TextSpan(
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
          out.add(_buildElement(node, tokens, onRecordTap));
        }
      }
    }
    flushInline();
    return out;
  }

  static Widget _buildElement(md.Element el, SurfaceTokens tokens, RecordTapCallback? onRecordTap) {
    switch (el.tag) {
      case 'h1':
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: _inlineText(el, tokens, onRecordTap, fontSize: 22, fontWeight: FontWeight.w500),
        );
      case 'h2':
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 10),
          child: _inlineText(el, tokens, onRecordTap, fontSize: 18, fontWeight: FontWeight.w500),
        );
      case 'h3':
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: _inlineText(el, tokens, onRecordTap, fontSize: 16, fontWeight: FontWeight.w500),
        );
      case 'h4':
      case 'h5':
      case 'h6':
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: _inlineText(el, tokens, onRecordTap, fontSize: clideFontBody, fontWeight: FontWeight.w600),
        );
      case 'p':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _inlineRichText(el, tokens, onRecordTap),
        );
      case 'ul':
        return Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in el.children ?? const [])
                if (c is md.Element) _buildListItem(c, tokens, onRecordTap, ordered: false)
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
                if (el.children![i] is md.Element) _buildListItem(el.children![i] as md.Element, tokens, onRecordTap, ordered: true, index: i + 1),
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
            children: _buildNodes(el.children?.cast<md.Node>() ?? const [], tokens, onRecordTap),
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
          child: _buildTable(el, tokens, onRecordTap),
        );
      default:
        return _inlineRichText(el, tokens, onRecordTap);
    }
  }

  static Widget _buildListItem(md.Element el, SurfaceTokens tokens, RecordTapCallback? onRecordTap, {bool ordered = false, int index = 1}) {
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
              children: _buildNodes(el.children?.cast<md.Node>() ?? const [], tokens, onRecordTap),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTable(md.Element table, SurfaceTokens tokens, RecordTapCallback? onRecordTap) {
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
            child: _inlineText(cell, tokens, onRecordTap, fontWeight: isHeader ? FontWeight.w600 : null),
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

  static Widget _inlineText(md.Element el, SurfaceTokens tokens, RecordTapCallback? onRecordTap, {double? fontSize, FontWeight? fontWeight}) {
    return RichText(text: _buildInlineSpan(el, tokens, onRecordTap, fontSize: fontSize, fontWeight: fontWeight));
  }

  static Widget _inlineRichText(md.Element el, SurfaceTokens tokens, RecordTapCallback? onRecordTap) {
    return RichText(text: _buildInlineSpan(el, tokens, onRecordTap));
  }

  static TextSpan _buildInlineSpan(md.Element el, SurfaceTokens tokens, RecordTapCallback? onRecordTap, {double? fontSize, FontWeight? fontWeight}) {
    final children = <InlineSpan>[];
    for (final child in el.children ?? const []) {
      if (child is md.Text) {
        children.add(TextSpan(text: _unescapeHtml(child.text)));
      } else if (child is md.Element) {
        children.add(_inlineElementSpan(child, tokens, onRecordTap));
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

  static InlineSpan _inlineElementSpan(md.Element el, SurfaceTokens tokens, RecordTapCallback? onRecordTap) {
    switch (el.tag) {
      case 'strong':
        return TextSpan(
          style: const TextStyle(fontWeight: FontWeight.w700),
          children: [
            for (final c in el.children ?? const [])
              if (c is md.Text) TextSpan(text: _unescapeHtml(c.text)) else if (c is md.Element) _inlineElementSpan(c, tokens, onRecordTap)
          ],
        );
      case 'em':
        return TextSpan(
          style: const TextStyle(fontStyle: FontStyle.italic),
          children: [
            for (final c in el.children ?? const [])
              if (c is md.Text) TextSpan(text: _unescapeHtml(c.text)) else if (c is md.Element) _inlineElementSpan(c, tokens, onRecordTap)
          ],
        );
      case 'code':
        return TextSpan(
          text: _unescapeHtml(el.textContent),
          style: TextStyle(fontFamily: clideMonoFamily, fontSize: clideFontMono, color: tokens.syntaxString, backgroundColor: tokens.panelBackground),
        );
      case 'a':
        final text = _unescapeHtml(el.textContent);
        if (onRecordTap != null && _recordPattern.hasMatch(text)) {
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ClideTappable(
              onTap: () => onRecordTap(text),
              builder: (_, hovered, __) => Text(
                text,
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
}
