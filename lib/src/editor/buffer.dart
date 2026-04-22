/// A buffer in the daemon's editor model.
///
/// Represents an open file: its on-disk path, the authoritative text
/// content, the UI's current cursor/selection, and whether it has
/// unsaved changes. Thin data class — the [EditorRegistry] owns the
/// transitions.
library;

class Selection {
  const Selection({required this.start, required this.end});

  const Selection.collapsed(int offset)
      : start = offset,
        end = offset;

  final int start;
  final int end;

  bool get isCollapsed => start == end;
  int get length => end - start;

  Map<String, Object?> toJson() => {'start': start, 'end': end};

  factory Selection.fromJson(Map<String, Object?> j) => Selection(
        start: (j['start'] as num).toInt(),
        end: (j['end'] as num).toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is Selection && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Selection($start-$end)';
}

class EditorBuffer {
  EditorBuffer({
    required this.id,
    required this.path,
    required this.content,
    Selection? selection,
    this.dirty = false,
  }) : selection = selection ?? const Selection.collapsed(0);

  /// Stable daemon-local id (`b_1`, `b_2`, …).
  final String id;

  /// Repo-relative path. Path is the identity key for "reopening the
  /// same file" — opening an already-open path returns the existing
  /// buffer.
  final String path;

  /// Authoritative text content. UI edits mutate this via IPC
  /// (`editor.insert`, `editor.replace-selection`); the UI's local
  /// copy reconciles to match.
  String content;

  /// Cursor / selection. Offsets are byte offsets into [content] —
  /// utf-8 characters that span multiple bytes count as multiple
  /// offsets, same convention Flutter's `TextEditingValue` uses.
  Selection selection;

  /// True after an edit landed that hasn't been persisted via
  /// `editor.save` (or `files.save` in future).
  bool dirty;

  Map<String, Object?> toJson() => {
        'id': id,
        'path': path,
        'length': content.length,
        'selection': selection.toJson(),
        'dirty': dirty,
      };

  /// Full snapshot including [content] — for `editor.read` / tests /
  /// anything that needs the text explicitly.
  Map<String, Object?> toFullJson() => {
        ...toJson(),
        'content': content,
      };
}
