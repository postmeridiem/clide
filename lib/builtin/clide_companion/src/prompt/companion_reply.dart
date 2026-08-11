/// Parsing what Clide says back (T-532, D-107 commitment 5).
///
/// His reply is a face on the first line and prose after it:
///
/// ```
/// [unimpressed]
/// The hook was being annoying about something.
/// ```
///
/// ## Why a prefix and not JSON or a tool
///
/// T-532 called for a bake-off between frontmatter and JSON, on the premise that
/// "there is **no structured-output enforcement** — the model's compliance is
/// the only guarantee there is". That premise was **wrong at CLI 2.1.226**:
/// `--json-schema` exists and really does enforce, via a forced `StructuredOutput`
/// tool call, returning a parsed object on the result event.
///
/// It was measured and rejected anyway, for two reasons the paper design could
/// not have known:
///
///  * **It costs about twice the output.** The model writes the prose, is then
///    handed a synthetic turn demanding the tool call, and restates the same
///    text inside it. Two round trips for one remark.
///  * **It cannot be silent.** A forced tool call means a reply every time, so
///    "say nothing" would have to be encoded as a field — and the hardest
///    instruction in the whole brief is that silence is usually right.
///
/// The prefix has neither problem and measured clean: **109 turns across five
/// tuning runs, zero malformed**. So the kill condition does not fire, and the
/// channel ships.
///
/// ## The kill condition still governs this file
///
/// Stability was measured, not assumed, and 109 turns is not infinity. So the
/// rules T-532 wrote for a failing format are implemented anyway, because the
/// cost of being wrong is a user watching `{"mood":` appear in Clide's mouth:
///
///  * **Strip aggressively.** Anything template-shaped that survives parsing is
///    removed from the displayed text rather than passed through.
///  * **An unreadable face keeps the previous expression** — never a default
///    reset, never a visible failure. A face that does not change is
///    indistinguishable from a companion with nothing new to feel; a face that
///    snaps to neutral is a glitch the user can see.
///  * **An unknown face name is no answer at all**, not a new state. The
///    vocabulary is closed and validated against the enum, because a mood the
///    painter cannot draw fails silently in a way that looks like it worked.
library;

import 'package:clide/builtin/clide_companion/src/face_state.dart';

/// What Clide said, once the scaffolding is off.
class CompanionReply {
  const CompanionReply({required this.face, required this.say});

  /// The face he named, or null when he named none we recognise.
  ///
  /// Null means **keep whatever is on screen**; it does not mean [FaceState.idle].
  /// The caller must not substitute a default — that is the visible-failure case
  /// this type exists to prevent.
  final FaceState? face;

  /// What to show in the bubble. Empty means he chose to say nothing, which is
  /// the common case and a complete answer, not an error.
  final String say;

  /// Whether anything should be shown at all.
  bool get speaks => say.isNotEmpty;

  @override
  String toString() => 'CompanionReply(${face?.name ?? '-'}, ${speaks ? '"$say"' : 'silent'})';
}

/// `[face]` on its own at the very start. Tolerates leading whitespace and a
/// missing newline, both of which have shown up in practice and neither of which
/// is worth discarding a good reply over.
final _facePrefix = RegExp(r'^\s*\[([A-Za-z]+)\]\s*');

/// Leftover scaffolding to strip from the visible text.
///
/// Belt and braces for shapes we have not seen but which the earlier designs
/// would have produced — a JSON envelope, a frontmatter fence, a second face tag
/// further down. Cheap to strip, and each one is a broken illusion if it lands
/// in the bubble.
final _scaffolding = <RegExp>[
  RegExp(r'^\s*```[a-z]*\s*', multiLine: true),
  RegExp(r'\s*```\s*$'),
  RegExp(r'^\s*\{\s*"(?:mood|face|say)"\s*:.*$', multiLine: true),
  RegExp(r'^\s*\[[A-Za-z]+\]\s*$', multiLine: true),
  RegExp(r'^\s*---\s*$', multiLine: true),
];

/// Face names, resolved once. Case-insensitive because the cost of rejecting
/// `[Idle]` is a frozen face and the benefit of strictness is nothing.
final Map<String, FaceState> _byName = {for (final f in FaceState.values) f.name.toLowerCase(): f};

/// Parse one reply.
///
/// Never throws and never returns null — a reply we cannot read is a reply with
/// no face and nothing to say, which renders as "he stayed quiet". That is a
/// correct outcome for a garbled turn, and it is invisible.
CompanionReply parseCompanionReply(String raw) {
  var text = raw;
  FaceState? face;

  final m = _facePrefix.firstMatch(text);
  if (m != null) {
    final named = _byName[m.group(1)!.toLowerCase()];
    // An unknown name is dropped rather than kept as text: it was meant as a
    // tag, and showing it would put scaffolding in his mouth. The face stays
    // null, so the previous expression holds.
    if (named != null && named.declarable) face = named;
    text = text.substring(m.end);
  } else if (text.trimLeft().startsWith('[')) {
    // **The tag is the first character, by design** — the brief says never to
    // write anything before the face. So a reply that opens with `[` and did not
    // parse as a tag is a broken one: truncated mid-write, or malformed. Either
    // way it is scaffolding, never prose, and the line goes.
    //
    // Checking the first character rather than hunting for a closing bracket is
    // both simpler and stricter: it also catches a tag that closed but is not a
    // tag (`[id le]`), which a look-for-the-`]` guard would have waved through.
    //
    // This is the guard timing cannot replace. [CompanionVoice] reads only at
    // the turn boundary, which removes the mid-stream case — but a reply cut off
    // at `max_tokens` part-way through its own tag arrives at that boundary
    // still broken.
    final br = text.indexOf('\n');
    text = br < 0 ? '' : text.substring(br + 1);
  }

  for (final re in _scaffolding) {
    text = text.replaceAll(re, '');
  }

  return CompanionReply(face: face, say: _tidy(text));
}

/// Collapse the whitespace a stripped reply leaves behind, and cap the damage a
/// runaway turn can do.
///
/// The cap is a backstop, not the length rule — the brief asks for one or two
/// sentences and gets them. This exists so that a turn which ignores the brief
/// entirely cannot push an essay into a strip that is ~110px tall.
String _tidy(String s) {
  final t = s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  if (t.length <= kMaxRemarkChars) return t;
  final cut = t.lastIndexOf(' ', kMaxRemarkChars);
  return '${t.substring(0, cut > 0 ? cut : kMaxRemarkChars).trimRight()}…';
}

/// Hard ceiling on a displayed remark. Generous against the brief's two
/// sentences; the point is that no reply can be unbounded.
const kMaxRemarkChars = 320;
