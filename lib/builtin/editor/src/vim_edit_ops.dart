/// Pure Vim normal/visual-mode motion + edit engine (T-206).
///
/// Operates on a [TextEditingValue] plus a yank [VimRegister] and returns
/// a [VimResult] — no widgets, no controller, no I/O — so the whole motion
/// grammar is unit-testable in isolation. The editor (`editor_view.dart`)
/// owns the thin wiring: it drives a [SequenceMatcher], and on a fired
/// `editor.vim.<action>` intent calls [applyVim] `count` times, applying
/// the result to its `EditableText` controller.
///
/// Scope is the muscle-memory set a Vim user reaches for first: hjkl /
/// w b e / 0 ^ $ / gg G motions, x dd D dw yy p P cc cw o O edits, the
/// i a I A insert entries, and d/y/c over a visual selection. It is a
/// faithful approximation, not a bit-exact Vim — counts apply by repeat,
/// and word motions use a three-class (word / punct / space) split.
library;

import 'package:flutter/services.dart' show TextEditingValue, TextSelection;

/// Action ids the `vim.yaml` preset binds to (as `command:editor.vim.<id>`).
/// Kept as constants so the preset, the editor dispatch, and the tests
/// agree on one spelling.
class VimAction {
  static const left = 'editor.vim.left';
  static const right = 'editor.vim.right';
  static const down = 'editor.vim.down';
  static const up = 'editor.vim.up';
  static const lineStart = 'editor.vim.lineStart';
  static const lineEnd = 'editor.vim.lineEnd';
  static const firstNonBlank = 'editor.vim.firstNonBlank';
  static const wordForward = 'editor.vim.wordForward';
  static const wordBackward = 'editor.vim.wordBackward';
  static const wordEnd = 'editor.vim.wordEnd';
  static const docStart = 'editor.vim.docStart';
  static const docEnd = 'editor.vim.docEnd';

  static const deleteChar = 'editor.vim.deleteChar';
  static const deleteLine = 'editor.vim.deleteLine';
  static const deleteToEnd = 'editor.vim.deleteToEnd';
  static const deleteWord = 'editor.vim.deleteWord';
  static const yankLine = 'editor.vim.yankLine';
  static const paste = 'editor.vim.paste';
  static const pasteBefore = 'editor.vim.pasteBefore';
  static const changeLine = 'editor.vim.changeLine';
  static const changeWord = 'editor.vim.changeWord';
  static const openBelow = 'editor.vim.openBelow';
  static const openAbove = 'editor.vim.openAbove';

  static const insert = 'editor.vim.insert';
  static const append = 'editor.vim.append';
  static const insertLineStart = 'editor.vim.insertLineStart';
  static const appendLineEnd = 'editor.vim.appendLineEnd';

  static const visualDelete = 'editor.vim.visualDelete';
  static const visualYank = 'editor.vim.visualYank';
  static const visualChange = 'editor.vim.visualChange';
}

/// The unnamed yank register. [linewise] yanks (from `dd`/`yy`) paste onto
/// a new line; charwise yanks paste inline.
class VimRegister {
  const VimRegister(this.text, {this.linewise = false});
  static const empty = VimRegister('');
  final String text;
  final bool linewise;
}

class VimResult {
  const VimResult(this.value, {this.register, this.enterInsert = false});

  final TextEditingValue value;

  /// Updated register, or null to leave it unchanged.
  final VimRegister? register;

  /// True when the op requests a switch to insert mode (c/o/i/a families).
  final bool enterInsert;
}

/// Apply [action] to [v]. [count] repeats motions/line-edits; [visual]
/// selects between collapse-to-caret (normal) and extend-from-anchor
/// (visual) for motions, and enables the `visual*` range ops.
VimResult applyVim(String action, TextEditingValue v, {VimRegister register = VimRegister.empty, bool visual = false, int count = 1}) {
  final t = v.text;
  final caret = v.selection.extentOffset.clamp(0, t.length);
  final anchor = v.selection.baseOffset.clamp(0, t.length);
  final n = count < 1 ? 1 : count;

  // --- Motions ----------------------------------------------------------
  final motion = _motions[action];
  if (motion != null) {
    var off = caret;
    for (var i = 0; i < n; i++) {
      off = motion(t, off);
    }
    final sel = visual ? TextSelection(baseOffset: anchor, extentOffset: off) : TextSelection.collapsed(offset: off);
    return VimResult(TextEditingValue(text: t, selection: sel));
  }

  // --- Insert-entry -----------------------------------------------------
  switch (action) {
    case VimAction.insert:
      return _insertAt(t, caret);
    case VimAction.append:
      return _insertAt(t, (caret < _lineEnd(t, caret)) ? caret + 1 : caret);
    case VimAction.insertLineStart:
      return _insertAt(t, _firstNonBlank(t, caret));
    case VimAction.appendLineEnd:
      return _insertAt(t, _lineEnd(t, caret));
  }

  // --- Edits ------------------------------------------------------------
  switch (action) {
    case VimAction.deleteChar:
      return _deleteChar(t, caret, n);
    case VimAction.deleteLine:
      return _deleteLines(t, caret, n);
    case VimAction.deleteToEnd:
      return _deleteToEnd(t, caret);
    case VimAction.deleteWord:
      return _deleteToOffset(t, caret, _repeat(_wordForward, t, caret, n));
    case VimAction.changeWord:
      return _deleteToOffset(t, caret, _repeat(_wordForward, t, caret, n), insert: true);
    case VimAction.yankLine:
      return _yankLines(t, caret, n);
    case VimAction.paste:
      return _paste(t, caret, register, before: false);
    case VimAction.pasteBefore:
      return _paste(t, caret, register, before: true);
    case VimAction.changeLine:
      return _changeLine(t, caret, n);
    case VimAction.openBelow:
      return _openLine(t, caret, below: true);
    case VimAction.openAbove:
      return _openLine(t, caret, below: false);
    case VimAction.visualDelete:
      return _deleteRange(t, anchor, caret, insert: false);
    case VimAction.visualChange:
      return _deleteRange(t, anchor, caret, insert: true);
    case VimAction.visualYank:
      return _yankRange(t, anchor, caret);
  }

  // Unknown action — no change.
  return VimResult(v);
}

// -- Motion table -----------------------------------------------------------

typedef _Motion = int Function(String t, int off);

final Map<String, _Motion> _motions = {
  VimAction.left: (t, o) => o > _lineStart(t, o) ? o - 1 : o,
  VimAction.right: (t, o) => o < _lineEnd(t, o) ? o + 1 : o,
  VimAction.down: _down,
  VimAction.up: _up,
  VimAction.lineStart: (t, o) => _lineStart(t, o),
  VimAction.lineEnd: (t, o) => _lineEnd(t, o),
  VimAction.firstNonBlank: _firstNonBlank,
  VimAction.wordForward: _wordForward,
  VimAction.wordBackward: _wordBackward,
  VimAction.wordEnd: _wordEnd,
  VimAction.docStart: (t, o) => 0,
  VimAction.docEnd: (t, o) => _firstNonBlank(t, _lineStart(t, t.length)),
};

int _repeat(_Motion m, String t, int off, int n) {
  var o = off;
  for (var i = 0; i < n; i++) {
    o = m(t, o);
  }
  return o;
}

// -- Offset helpers ---------------------------------------------------------

int _clamp(int x, int lo, int hi) => x < lo ? lo : (x > hi ? hi : x);

int _lineStart(String t, int off) {
  if (off <= 0) return 0;
  final i = t.lastIndexOf('\n', off - 1);
  return i < 0 ? 0 : i + 1;
}

/// Offset of the newline ending [off]'s line, or [t].length on the last line.
int _lineEnd(String t, int off) {
  final i = t.indexOf('\n', off);
  return i < 0 ? t.length : i;
}

int _firstNonBlank(String t, int off) {
  final ls = _lineStart(t, off);
  final le = _lineEnd(t, off);
  var i = ls;
  while (i < le && (t[i] == ' ' || t[i] == '\t')) {
    i++;
  }
  return i;
}

int _down(String t, int off) {
  final ls = _lineStart(t, off);
  final le = _lineEnd(t, off);
  if (le >= t.length) return off; // last line
  final col = off - ls;
  final nls = le + 1;
  final nle = _lineEnd(t, nls);
  return _clamp(nls + col, nls, nle);
}

int _up(String t, int off) {
  final ls = _lineStart(t, off);
  if (ls == 0) return off; // first line
  final col = off - ls;
  final pls = _lineStart(t, ls - 1);
  final ple = ls - 1; // the newline ending the previous line
  return _clamp(pls + col, pls, ple);
}

// 0 = whitespace, 1 = word char, 2 = punctuation.
int _cls(String ch) {
  if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') return 0;
  final c = ch.codeUnitAt(0);
  final isWord =
      (c >= 0x30 && c <= 0x39) || // 0-9
      (c >= 0x41 && c <= 0x5A) || // A-Z
      (c >= 0x61 && c <= 0x7A) || // a-z
      c == 0x5F; // _
  return isWord ? 1 : 2;
}

int _wordForward(String t, int off) {
  var i = off;
  if (i >= t.length) return t.length;
  final start = _cls(t[i]);
  if (start != 0) {
    while (i < t.length && _cls(t[i]) == start) {
      i++;
    }
  }
  while (i < t.length && _cls(t[i]) == 0) {
    i++;
  }
  return i;
}

int _wordBackward(String t, int off) {
  var i = off;
  if (i <= 0) return 0;
  i--;
  while (i > 0 && _cls(t[i]) == 0) {
    i--;
  }
  final cls = _cls(t[i]);
  while (i > 0 && _cls(t[i - 1]) == cls && cls != 0) {
    i--;
  }
  return i;
}

int _wordEnd(String t, int off) {
  if (t.isEmpty) return 0;
  var i = off + 1;
  while (i < t.length && _cls(t[i]) == 0) {
    i++;
  }
  if (i >= t.length) return t.length - 1;
  final cls = _cls(t[i]);
  while (i + 1 < t.length && _cls(t[i + 1]) == cls) {
    i++;
  }
  return i;
}

// -- Edit helpers -----------------------------------------------------------

VimResult _collapsed(String text, int caret) => VimResult(
  TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: _clamp(caret, 0, text.length)),
  ),
);

VimResult _insertAt(String t, int caret) => VimResult(
  TextEditingValue(
    text: t,
    selection: TextSelection.collapsed(offset: _clamp(caret, 0, t.length)),
  ),
  enterInsert: true,
);

VimResult _deleteChar(String t, int caret, int count) {
  final le = _lineEnd(t, caret);
  final end = _clamp(caret + count, caret, le);
  if (end == caret) return _collapsed(t, caret);
  final removed = t.substring(caret, end);
  final nt = t.replaceRange(caret, end, '');
  // Keep the caret on a real char: clamp to the (new) last char of the line.
  final nls = _lineStart(nt, caret);
  final nle = _lineEnd(nt, caret);
  final ncaret = _clamp(caret, nls, nle > nls ? nle - 1 : nls);
  return VimResult(
    TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: ncaret),
    ),
    register: VimRegister(removed),
  );
}

VimResult _deleteLines(String t, int caret, int count) {
  final ls = _lineStart(t, caret);
  var end = ls;
  for (var i = 0; i < count; i++) {
    final le = _lineEnd(t, end);
    end = le < t.length ? le + 1 : le;
    if (le >= t.length) break;
  }
  final removed = t.substring(ls, end);
  final reg = VimRegister(removed.endsWith('\n') ? removed : '$removed\n', linewise: true);
  String nt;
  int caretLineStart;
  if (end >= t.length && ls > 0) {
    // Removed the final line(s): drop the preceding newline too.
    nt = t.substring(0, ls - 1);
    caretLineStart = _lineStart(nt, nt.length);
  } else {
    nt = t.replaceRange(ls, end, '');
    caretLineStart = ls;
  }
  return VimResult(
    TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: _firstNonBlank(nt, caretLineStart)),
    ),
    register: reg,
  );
}

VimResult _deleteToEnd(String t, int caret) {
  final le = _lineEnd(t, caret);
  if (le == caret) return _collapsed(t, caret);
  final removed = t.substring(caret, le);
  final nt = t.replaceRange(caret, le, '');
  final ls = _lineStart(nt, caret);
  final nle = _lineEnd(nt, caret);
  return VimResult(
    TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: _clamp(caret, ls, nle > ls ? nle - 1 : ls)),
    ),
    register: VimRegister(removed),
  );
}

VimResult _deleteToOffset(String t, int caret, int target, {bool insert = false}) {
  final lo = caret < target ? caret : target;
  final hi = caret < target ? target : caret;
  if (lo == hi) return insert ? _insertAt(t, caret) : _collapsed(t, caret);
  final removed = t.substring(lo, hi);
  final nt = t.replaceRange(lo, hi, '');
  return VimResult(
    TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: lo),
    ),
    register: VimRegister(removed),
    enterInsert: insert,
  );
}

VimResult _changeLine(String t, int caret, int count) {
  // Like dd but keep one (empty) line and enter insert at its indent.
  final ls = _lineStart(t, caret);
  var end = ls;
  for (var i = 0; i < count; i++) {
    end = _lineEnd(t, end);
    if (i < count - 1 && end < t.length) end++;
  }
  final removed = t.substring(ls, end);
  final nt = t.replaceRange(ls, end, '');
  return VimResult(
    TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: ls),
    ),
    register: VimRegister(removed.endsWith('\n') ? removed : '$removed\n', linewise: true),
    enterInsert: true,
  );
}

VimResult _yankLines(String t, int caret, int count) {
  final ls = _lineStart(t, caret);
  var end = ls;
  for (var i = 0; i < count; i++) {
    final le = _lineEnd(t, end);
    end = le < t.length ? le + 1 : le;
    if (le >= t.length) break;
  }
  final yanked = t.substring(ls, end);
  return VimResult(
    TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: caret),
    ),
    register: VimRegister(yanked.endsWith('\n') ? yanked : '$yanked\n', linewise: true),
  );
}

VimResult _paste(String t, int caret, VimRegister reg, {required bool before}) {
  if (reg.text.isEmpty) return _collapsed(t, caret);
  if (reg.linewise) {
    final body = reg.text.endsWith('\n') ? reg.text : '${reg.text}\n';
    if (before) {
      final ls = _lineStart(t, caret);
      final nt = t.replaceRange(ls, ls, body);
      return VimResult(
        TextEditingValue(
          text: nt,
          selection: TextSelection.collapsed(offset: _firstNonBlank(nt, ls)),
        ),
      );
    }
    final le = _lineEnd(t, caret);
    final insertAt = le < t.length ? le + 1 : t.length;
    // On the last line (no trailing newline) we must add a leading newline.
    final chunk = le < t.length ? body : '\n${body.substring(0, body.length - 1)}';
    final nt = t.replaceRange(insertAt, insertAt, chunk);
    final caretLine = le < t.length ? insertAt : insertAt + 1;
    return VimResult(
      TextEditingValue(
        text: nt,
        selection: TextSelection.collapsed(offset: _firstNonBlank(nt, caretLine)),
      ),
    );
  }
  // Charwise: p pastes after the caret, P at the caret.
  final at = before ? caret : _clamp(caret + 1, 0, t.length);
  final nt = t.replaceRange(at, at, reg.text);
  return VimResult(
    TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: at + reg.text.length - 1),
    ),
  );
}

VimResult _openLine(String t, int caret, {required bool below}) {
  if (below) {
    final le = _lineEnd(t, caret);
    final nt = t.replaceRange(le, le, '\n');
    return VimResult(
      TextEditingValue(
        text: nt,
        selection: TextSelection.collapsed(offset: le + 1),
      ),
      enterInsert: true,
    );
  }
  final ls = _lineStart(t, caret);
  final nt = t.replaceRange(ls, ls, '\n');
  return VimResult(
    TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: ls),
    ),
    enterInsert: true,
  );
}

VimResult _deleteRange(String t, int anchor, int caret, {required bool insert}) {
  final lo = anchor < caret ? anchor : caret;
  // Visual selection in Vim is inclusive of the char under the caret.
  final hi = _clamp((anchor < caret ? caret : anchor) + 1, 0, t.length);
  if (lo == hi) return insert ? _insertAt(t, lo) : _collapsed(t, lo);
  final removed = t.substring(lo, hi);
  final nt = t.replaceRange(lo, hi, '');
  return VimResult(
    TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: lo),
    ),
    register: VimRegister(removed),
    enterInsert: insert,
  );
}

VimResult _yankRange(String t, int anchor, int caret) {
  final lo = anchor < caret ? anchor : caret;
  final hi = _clamp((anchor < caret ? caret : anchor) + 1, 0, t.length);
  return VimResult(
    TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: lo),
    ),
    register: VimRegister(t.substring(lo, hi)),
  );
}
