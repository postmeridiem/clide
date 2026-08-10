/// Composing Clide's system prompt (T-532, D-107).
///
/// The brief itself is an asset, not a string literal —
/// `assets/clide/prompts/<locale>/clide-brief.md`, resolved through the same
/// fallback chain the i18n service walks. This file only fills in the parts that
/// cannot be written into a static document: who the developer is, what language
/// to answer in, and which faces exist.
///
/// ## Why the brief is an asset and not a catalog key
///
/// D-21/D-102 route authored text through the catalog, and T-532 originally
/// proposed keys (`prompt.system`, `prompt.digest.observed`, …). The cost is a
/// hard one: `i18n_coverage_test.dart` enforces key parity between every shipped
/// locale, so a catalogued system prompt obliges a Dutch system prompt kept in
/// lockstep forever — and prompts are tuned iteratively, so every tuning pass
/// becomes two.
///
/// A locale-routed **document** gets the same reach without the obligation. A
/// native brief is a file someone adds; until one exists the chain falls through
/// to `en_us` and nothing is half-translated. When one does exist it produces
/// better register than an English prompt asking for Dutch, because the whole
/// context is Dutch rather than one line requesting it.
///
/// **This resolves the tension D-107 flagged**, and D-107's line is amended to
/// match: the locale reaches Clide through the prompt document, and — because
/// the document differs per locale — a language change means a restart (T-558).
///
/// ## Why the face list is injected
///
/// `{faces}` is derived from [kDeclarableFaces] rather than typed into the
/// brief. A vocabulary written in two places drifts, and the failure is silent
/// in the worst direction: the model names a mood, the parser rejects it, and
/// the face simply never changes. Deriving it means adding a state reaches the
/// prompt without anyone remembering to.
library;

import 'package:clide/builtin/clide_companion/src/face_state.dart';

/// Placeholder names in the brief. Kept as constants because a typo in either
/// half is a silently unfilled prompt.
const kAboutPlaceholder = '{about}';
const kLanguagePlaceholder = '{language}';
const kFacesPlaceholder = '{faces}';

/// Language names for the locales clide ships, keyed by [FallbackChain]-style
/// suffix.
///
/// A name, not a tag: "Dutch" is followed more reliably than "nl-NL", which a
/// model may read as a formatting instruction rather than a language. Unknown
/// locales fall through to the tag, which is still better than nothing.
const _languageNames = <String, String>{'en_us': 'English', 'en': 'English', 'nl_nl': 'Dutch', 'nl': 'Dutch', 'nl_be': 'Dutch'};

/// The language name to instruct with, for a locale suffix like `nl_nl`.
String languageNameFor(String localeSuffix) => _languageNames[localeSuffix.toLowerCase()] ?? localeSuffix;

/// Fill [brief]'s placeholders.
///
/// [name] and [about] are the developer's own, from settings, and both are
/// optional — a companion given nothing simply gets no personal section rather
/// than a sentence full of blanks. They are injected **once, here**, and never
/// repeated in the digest: the transcript uses neutral speaker labels, so his
/// context knows who he is watching without every line carrying a name.
String composeSystemPrompt({required String brief, required String localeSuffix, String? name, String? about, List<FaceState>? faces}) {
  final vocabulary = (faces ?? kDeclarableFaces).map((f) => '[${f.name}]').join(' ');
  return _stripAuthoringNotes(brief)
      .replaceAll(kAboutPlaceholder, _aboutBlock(name, about))
      .replaceAll(kLanguagePlaceholder, languageNameFor(localeSuffix))
      .replaceAll(kFacesPlaceholder, vocabulary)
      .trim();
}

/// HTML comments in the brief are notes to **us**, and must never reach him.
///
/// Caught on the first live launch (2026-08-10): the brief opens with a comment
/// explaining why the file exists — ticket numbers, the fallback chain, the a11y
/// parity test, "tuned against Haiku 4.5 over 109 turns" — and every word of it
/// was going into the system prompt. Roughly two hundred tokens telling Clide he
/// is a construct, four paragraphs above the rule forbidding him to mention that
/// he is one.
///
/// Stripped at compose time rather than deleted from the file: the rationale is
/// exactly the kind of thing that must live beside the text it explains, or the
/// next person to tune the prompt does it blind.
String _stripAuthoringNotes(String brief) => brief.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// The "who you are watching" paragraph, or empty when nothing is known.
///
/// Empty rather than a default: "The developer you are watching is called the
/// user" is worse than silence, and an unfilled placeholder in a system prompt
/// is the kind of thing that reads as a bug when it eventually surfaces in a
/// reply.
String _aboutBlock(String? name, String? about) {
  final n = name?.trim() ?? '';
  final a = about?.trim() ?? '';
  if (n.isEmpty && a.isEmpty) return '';
  final buf = StringBuffer('## Who you are watching\n\n');
  if (n.isNotEmpty) {
    buf.write('The developer is called $n. You know that, and you do not use it — a companion who says your name back to you sounds like a salesperson.');
  }
  if (a.isNotEmpty) {
    if (n.isNotEmpty) buf.write(' ');
    buf.write('In their own words:\n\n> $a');
  }
  return buf.toString();
}
