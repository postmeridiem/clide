import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/src/clide_code_block.dart';
import 'package:clide/widgets/src/clide_divider.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;

class ClideMarkdown extends StatelessWidget {
  const ClideMarkdown(this.source, {super.key});

  final String source;

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
    final cleaned = _unescapeHtml(source);
    final doc = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
    final nodes = doc.parseLines(cleaned.split('\n'));
    final widgets = _buildNodes(nodes, tokens);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  static List<Widget> _buildNodes(List<md.Node> nodes, SurfaceTokens tokens) {
    final out = <Widget>[];
    for (final node in nodes) {
      if (node is md.Element) {
        out.add(_buildElement(node, tokens));
      } else if (node is md.Text) {
        out.add(ClideText(node.text, fontSize: clideFontBody));
      }
    }
    return out;
  }

  static Widget _buildElement(md.Element el, SurfaceTokens tokens) {
    switch (el.tag) {
      case 'h1':
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: _inlineText(el, tokens, fontSize: 22, fontWeight: FontWeight.w500),
        );
      case 'h2':
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: _inlineText(el, tokens, fontSize: 18, fontWeight: FontWeight.w500),
        );
      case 'h3':
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: _inlineText(el, tokens, fontSize: 16, fontWeight: FontWeight.w500),
        );
      case 'h4':
      case 'h5':
      case 'h6':
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: _inlineText(el, tokens, fontSize: clideFontBody, fontWeight: FontWeight.w600),
        );
      case 'p':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _inlineRichText(el, tokens),
        );
      case 'ul':
        return Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [for (final c in el.children ?? const []) if (c is md.Element) _buildListItem(c, tokens, ordered: false)],
          ),
        );
      case 'ol':
        return Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < (el.children?.length ?? 0); i++)
                if (el.children![i] is md.Element) _buildListItem(el.children![i] as md.Element, tokens, ordered: true, index: i + 1),
            ],
          ),
        );
      case 'blockquote':
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: tokens.globalTextMuted, width: 3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: _buildNodes(el.children?.cast<md.Node>() ?? const [], tokens),
          ),
        );
      case 'pre':
        final codeEl = el.children?.whereType<md.Element>().firstOrNull;
        final code = codeEl?.textContent ?? el.textContent;
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
          child: _buildTable(el, tokens),
        );
      default:
        return _inlineRichText(el, tokens);
    }
  }

  static Widget _buildListItem(md.Element el, SurfaceTokens tokens, {bool ordered = false, int index = 1}) {
    final bullet = ordered ? '$index. ' : '• ';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClideText(bullet, color: tokens.globalTextMuted, fontSize: clideFontBody),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: _buildNodes(el.children?.cast<md.Node>() ?? const [], tokens),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTable(md.Element table, SurfaceTokens tokens) {
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
            child: _inlineText(cell, tokens, fontWeight: isHeader ? FontWeight.w600 : null),
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

  static Widget _inlineText(md.Element el, SurfaceTokens tokens, {double? fontSize, FontWeight? fontWeight}) {
    return RichText(text: _buildInlineSpan(el, tokens, fontSize: fontSize, fontWeight: fontWeight));
  }

  static Widget _inlineRichText(md.Element el, SurfaceTokens tokens) {
    return RichText(text: _buildInlineSpan(el, tokens));
  }

  static TextSpan _buildInlineSpan(md.Element el, SurfaceTokens tokens, {double? fontSize, FontWeight? fontWeight}) {
    final children = <InlineSpan>[];
    for (final child in el.children ?? const []) {
      if (child is md.Text) {
        children.add(TextSpan(text: child.text));
      } else if (child is md.Element) {
        children.add(_inlineElementSpan(child, tokens));
      }
    }
    return TextSpan(
      style: TextStyle(
        color: tokens.globalForeground,
        fontSize: fontSize ?? clideFontBody,
        fontWeight: fontWeight,
      ),
      children: children,
    );
  }

  static TextSpan _inlineElementSpan(md.Element el, SurfaceTokens tokens) {
    switch (el.tag) {
      case 'strong':
        return TextSpan(
          style: const TextStyle(fontWeight: FontWeight.w700),
          children: [for (final c in el.children ?? const []) if (c is md.Text) TextSpan(text: c.text) else if (c is md.Element) _inlineElementSpan(c, tokens)],
        );
      case 'em':
        return TextSpan(
          style: const TextStyle(fontStyle: FontStyle.italic),
          children: [for (final c in el.children ?? const []) if (c is md.Text) TextSpan(text: c.text) else if (c is md.Element) _inlineElementSpan(c, tokens)],
        );
      case 'code':
        return TextSpan(
          text: el.textContent,
          style: TextStyle(fontFamily: clideMonoFamily, fontSize: clideFontMono, color: tokens.syntaxString, backgroundColor: tokens.panelBackground),
        );
      case 'a':
        return TextSpan(
          text: el.textContent,
          style: TextStyle(color: tokens.globalFocus),
        );
      case 'del':
        return TextSpan(
          text: el.textContent,
          style: TextStyle(decoration: TextDecoration.lineThrough, color: tokens.globalTextMuted),
        );
      default:
        return TextSpan(text: el.textContent);
    }
  }
}
