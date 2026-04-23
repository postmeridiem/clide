import 'dart:convert';

import 'package:clide/kernel/src/syntax/tree_sitter_service.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

class ClideCodeBlock extends StatefulWidget {
  const ClideCodeBlock({super.key, required this.source, this.language});

  final String source;
  final String? language;

  @override
  State<ClideCodeBlock> createState() => _ClideCodeBlockState();
}

class _ClideCodeBlockState extends State<ClideCodeBlock> {
  final TreeSitterService _syntax = TreeSitterService();
  List<SyntaxSpan>? _spans;

  @override
  void initState() {
    super.initState();
    _highlight();
  }

  @override
  void didUpdateWidget(ClideCodeBlock old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source || old.language != widget.language) {
      _highlight();
    }
  }

  @override
  void dispose() {
    _syntax.dispose();
    super.dispose();
  }

  Future<void> _highlight() async {
    final lang = widget.language;
    if (lang == null || lang.isEmpty) {
      setState(() => _spans = null);
      return;
    }
    final path = 'code.$lang';
    if (!await _syntax.hasGrammar(path)) {
      setState(() => _spans = null);
      return;
    }
    final result = await _syntax.highlight(path, widget.source);
    if (mounted) setState(() => _spans = result.spans);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final style = TextStyle(
      fontFamily: clideMonoFamily,
      fontFamilyFallback: clideMonoFamilyFallback,
      fontSize: clideFontMono,
      color: tokens.globalForeground,
    );

    final spans = _spans;
    TextSpan textSpan;

    if (spans == null || spans.isEmpty) {
      textSpan = TextSpan(text: widget.source, style: style);
    } else {
      textSpan = _buildHighlightedSpan(widget.source, spans, style, tokens);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: RichText(text: textSpan),
      ),
    );
  }

  static TextSpan _buildHighlightedSpan(String source, List<SyntaxSpan> spans, TextStyle base, dynamic tokens) {
    final bytes = utf8.encode(source);
    final byteToChar = List<int>.filled(bytes.length + 1, source.length);
    var bi = 0;
    for (var ci = 0; ci < source.length; ci++) {
      byteToChar[bi] = ci;
      final rune = source.codeUnitAt(ci);
      if (rune < 0x80) {
        bi += 1;
      } else if (rune < 0x800) {
        bi += 2;
      } else if (rune >= 0xD800 && rune <= 0xDBFF) {
        bi += 4;
        ci++;
      } else {
        bi += 3;
      }
    }
    byteToChar[bi] = source.length;

    final sorted = List.of(spans)..sort((a, b) => a.start.compareTo(b.start));
    final children = <TextSpan>[];
    var lastChar = 0;

    for (final span in sorted) {
      final sChar = span.start < byteToChar.length ? byteToChar[span.start] : source.length;
      final eChar = span.end < byteToChar.length ? byteToChar[span.end] : source.length;
      if (sChar > lastChar) {
        children.add(TextSpan(text: source.substring(lastChar, sChar)));
      }
      if (eChar > sChar) {
        final color = TreeSitterService.colorForRole(span.role, tokens);
        children.add(TextSpan(text: source.substring(sChar, eChar), style: base.copyWith(color: color)));
      }
      lastChar = eChar;
    }
    if (lastChar < source.length) {
      children.add(TextSpan(text: source.substring(lastChar)));
    }

    return TextSpan(style: base, children: children);
  }
}
