/// [EditorSettings] — the effective, source-agnostic editor configuration for
/// one file (T-29).
///
/// The editor surface and the save path obey *this* object, never a particular
/// source file. Today the only source is the project's `.editorconfig` (parsed
/// in `editorconfig.dart`), but a settings panel or a clide-owned settings file
/// can layer in later via [merge] without the editor, registry, or save path
/// changing — that is the whole point of routing everything through one model.
///
/// Flutter-free (no `dart:io`, no `dart:ui`): it travels from the daemon to the
/// UI as plain JSON and is unit-tested under `dart test`.
library;

class EditorSettings {
  const EditorSettings({
    this.indentStyle,
    this.indentSize,
    this.tabWidth,
    this.endOfLine,
    this.maxLineLength,
    this.trimTrailingWhitespace,
    this.insertFinalNewline,
  });

  /// `tab` or `space`.
  final String? indentStyle;

  /// Columns per indent level.
  final int? indentSize;

  /// Width of a tab character.
  final int? tabWidth;

  /// `lf`, `crlf`, or `cr`.
  final String? endOfLine;

  /// Ruler / wrap-guide column. Null when unset.
  final int? maxLineLength;

  final bool? trimTrailingWhitespace;
  final bool? insertFinalNewline;

  /// Nothing set — the editor keeps all of its built-in defaults.
  static const empty = EditorSettings();

  bool get isEmpty =>
      indentStyle == null &&
      indentSize == null &&
      tabWidth == null &&
      endOfLine == null &&
      maxLineLength == null &&
      trimTrailingWhitespace == null &&
      insertFinalNewline == null;

  /// The line terminator [endOfLine] names, or null when unset.
  String? get eolString => switch (endOfLine) {
    'lf' => '\n',
    'crlf' => '\r\n',
    'cr' => '\r',
    _ => null,
  };

  /// The text one Tab press inserts, or null to keep the editor's default
  /// (Flutter's focus traversal) — the editor only takes over Tab when a source
  /// has an opinion about indentation.
  String? get indentUnit {
    if (indentStyle == 'tab') return '\t';
    if (indentStyle == 'space') return ' ' * (indentSize ?? 4);
    if (indentSize != null) return ' ' * indentSize!; // a size with no style → spaces
    return null;
  }

  /// Layer [other] on top: every field [other] sets overrides this one, fields
  /// it leaves null fall through. The composition order (lowest precedence
  /// first) lives in the resolver — a higher-precedence source (settings panel,
  /// clide settings file) merges over a lower one (.editorconfig).
  EditorSettings merge(EditorSettings other) => EditorSettings(
    indentStyle: other.indentStyle ?? indentStyle,
    indentSize: other.indentSize ?? indentSize,
    tabWidth: other.tabWidth ?? tabWidth,
    endOfLine: other.endOfLine ?? endOfLine,
    maxLineLength: other.maxLineLength ?? maxLineLength,
    trimTrailingWhitespace: other.trimTrailingWhitespace ?? trimTrailingWhitespace,
    insertFinalNewline: other.insertFinalNewline ?? insertFinalNewline,
  );

  /// Only the set keys, for the IPC payload. Empty map when [isEmpty].
  Map<String, Object?> toJson() => {
    if (indentStyle != null) 'indent_style': indentStyle,
    if (indentSize != null) 'indent_size': indentSize,
    if (tabWidth != null) 'tab_width': tabWidth,
    if (endOfLine != null) 'end_of_line': endOfLine,
    if (maxLineLength != null) 'max_line_length': maxLineLength,
    if (trimTrailingWhitespace != null) 'trim_trailing_whitespace': trimTrailingWhitespace,
    if (insertFinalNewline != null) 'insert_final_newline': insertFinalNewline,
  };

  factory EditorSettings.fromJson(Object? raw) {
    if (raw is! Map) return empty;
    return EditorSettings(
      indentStyle: raw['indent_style'] as String?,
      indentSize: (raw['indent_size'] as num?)?.toInt(),
      tabWidth: (raw['tab_width'] as num?)?.toInt(),
      endOfLine: raw['end_of_line'] as String?,
      maxLineLength: (raw['max_line_length'] as num?)?.toInt(),
      trimTrailingWhitespace: raw['trim_trailing_whitespace'] as bool?,
      insertFinalNewline: raw['insert_final_newline'] as bool?,
    );
  }

  /// Apply the on-save text fixes these settings request: end-of-line
  /// normalization, trailing-whitespace trimming, and final-newline
  /// insertion/removal. Returns [content] unchanged where nothing is set.
  String applyOnSave(String content) {
    if (content.isEmpty) return content;
    var out = content;

    // Trim trailing spaces/tabs before any line break or end-of-string. Done
    // first and EOL-agnostically so it composes with the EOL rewrite below.
    if (trimTrailingWhitespace == true) {
      out = out.replaceAll(RegExp(r'[ \t]+(?=\r\n|\r|\n|$)'), '');
    }

    final eol = eolString;
    if (eol != null) {
      out = out.replaceAll(RegExp(r'\r\n|\r|\n'), eol);
    }

    if (insertFinalNewline == true) {
      if (out.isNotEmpty && !out.endsWith('\n') && !out.endsWith('\r')) {
        out += eol ?? _detectEol(out) ?? '\n';
      }
    } else if (insertFinalNewline == false) {
      out = out.replaceAll(RegExp(r'(\r\n|\r|\n)+$'), '');
    }
    return out;
  }

  static String? _detectEol(String s) => RegExp(r'\r\n|\r|\n').firstMatch(s)?.group(0);
}
