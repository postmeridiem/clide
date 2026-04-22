library;

import 'dart:convert';

import 'package:clide_app/kernel/src/syntax/language_map.dart';
import 'package:clide_app/kernel/src/syntax/tree_sitter_service.dart';
import 'package:clide_app/kernel/src/theme/tokens.dart';
import 'package:flutter/widgets.dart';

class SyntaxTextController extends TextEditingController {
  SyntaxTextController({required TreeSitterService syntax})
      : _syntax = syntax;

  final TreeSitterService _syntax;

  String? _highlightedPath;
  String? _highlightedText;
  List<SyntaxSpan> _spans = const [];
  SurfaceTokens? _tokens;
  bool _highlighting = false;

  set tokens(SurfaceTokens value) => _tokens = value;

  void updatePath(String? path) {
    if (path == _highlightedPath) return;
    _highlightedPath = path;
    _spans = const [];
    _highlightedText = null;
    _requestHighlight();
  }

  void _requestHighlight() {
    final path = _highlightedPath;
    final source = text;
    if (path == null || source.isEmpty || _highlighting) return;
    if (grammarForPath(path) == null) return;
    if (source == _highlightedText) return;

    _highlighting = true;
    _syntax.highlight(path, source).then((result) {
      _highlighting = false;
      if (text != source) {
        _requestHighlight();
        return;
      }
      _highlightedText = source;
      _spans = result.spans;
      notifyListeners();
    }, onError: (_) {
      _highlighting = false;
    });
  }

  @override
  set value(TextEditingValue newValue) {
    super.value = newValue;
    _requestHighlight();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final tokens = _tokens;
    if (_spans.isEmpty || tokens == null || text.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final source = text;
    final sourceBytes = utf8.encode(source);
    final children = <TextSpan>[];

    // Convert byte offsets to character offsets.
    // Build a byte-to-char map only up to the max byte we need.
    final spans = _spans.where((s) => s.end <= sourceBytes.length).toList()
      ..sort((a, b) => a.start != b.start ? a.start - b.start : a.end - b.end);

    if (spans.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    int maxByte = 0;
    for (final s in spans) {
      if (s.end > maxByte) maxByte = s.end;
    }

    // byte offset -> char offset lookup.
    final byteToChar = List<int>.filled(maxByte + 1, 0);
    int charIdx = 0;
    int byteIdx = 0;
    while (byteIdx <= maxByte && charIdx <= source.length) {
      byteToChar[byteIdx] = charIdx;
      if (charIdx < source.length) {
        final codeUnit = source.codeUnitAt(charIdx);
        // UTF-16 surrogate pair = 4 bytes in UTF-8.
        if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
          final bytesForPair = utf8.encode(source.substring(charIdx, charIdx + 2)).length;
          for (var b = 1; b < bytesForPair && byteIdx + b <= maxByte; b++) {
            byteToChar[byteIdx + b] = charIdx;
          }
          byteIdx += bytesForPair;
          charIdx += 2;
        } else {
          final bytesForChar = utf8.encode(source[charIdx]).length;
          for (var b = 1; b < bytesForChar && byteIdx + b <= maxByte; b++) {
            byteToChar[byteIdx + b] = charIdx;
          }
          byteIdx += bytesForChar;
          charIdx++;
        }
      } else {
        break;
      }
    }

    int charPos = 0;
    for (final span in spans) {
      if (span.start >= sourceBytes.length || span.end > sourceBytes.length) {
        continue;
      }
      final spanCharStart = byteToChar[span.start];
      final spanCharEnd = span.end <= maxByte
          ? byteToChar[span.end]
          : source.length;

      if (spanCharStart < charPos) continue;

      // Gap before this span — plain text.
      if (spanCharStart > charPos) {
        children.add(TextSpan(
          text: source.substring(charPos, spanCharStart),
          style: style,
        ));
      }

      // The highlighted span.
      if (spanCharEnd > spanCharStart) {
        children.add(TextSpan(
          text: source.substring(spanCharStart, spanCharEnd),
          style: style?.copyWith(
            color: TreeSitterService.colorForRole(span.role, tokens),
          ),
        ));
      }

      charPos = spanCharEnd;
    }

    // Trailing plain text.
    if (charPos < source.length) {
      children.add(TextSpan(
        text: source.substring(charPos),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}
