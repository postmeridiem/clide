/// Loading Clide's brief off the locale-routed asset path (T-532).
///
/// The thin half of the prompt work: everything interesting is in
/// [composeSystemPrompt], which is pure and testable without Flutter. This is
/// only the bridge from `rootBundle` to that.
///
/// Walks the **same** [FallbackChain] as the i18n catalogs — `nl_NL → nl →
/// en_US → en` — and takes the first document that exists, so a locale with no
/// brief of its own gets English rather than nothing. That is the whole reason
/// the brief is a document instead of catalog keys: a missing key fails parity,
/// a missing document falls through.
library;

import 'dart:ui' show Locale;

import 'package:clide/kernel/src/i18n/fallback_chain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Where the briefs live. One folder per locale, matching `assets/i18n/`.
const kPromptRoot = 'assets/clide/prompts';

/// Filename of the brief within a locale folder.
const kBriefAsset = 'clide-brief.md';

/// The brief for [locale], and the locale suffix it was actually found under.
///
/// The suffix is returned rather than assumed because it is what
/// [composeSystemPrompt] names as the reply language: if a Dutch user falls
/// through to the English brief, the instruction inside it must still say
/// **Dutch**, or falling back would silently change what language he answers in.
/// That is the one place where "which file did we load" and "what language does
/// he speak" must deliberately disagree.
typedef LoadedBrief = ({String text, String foundIn});

/// Read the first brief that exists along [locale]'s fallback chain.
///
/// Returns null when none does — which in a shipped build means the asset was
/// not bundled, i.e. a packaging bug rather than a runtime condition. The caller
/// treats it as "no companion", because a session spawned with no brief is a
/// generic assistant wearing Clide's face, which is worse than no companion.
Future<LoadedBrief?> loadCompanionBrief({required Locale locale, Locale defaultLocale = const Locale('en', 'US'), AssetBundle? bundle}) async {
  final b = bundle ?? rootBundle;
  for (final l in FallbackChain(current: locale, defaultLocale: defaultLocale).resolve()) {
    final suffix = FallbackChain.filenameSuffix(l);
    try {
      final text = await b.loadString('$kPromptRoot/$suffix/$kBriefAsset');
      if (text.trim().isNotEmpty) return (text: text, foundIn: suffix);
    } on FlutterError {
      // Not bundled for this locale — that is the fallback chain working, not
      // an error. Try the next one.
      continue;
    }
  }
  return null;
}

/// The suffix used to name the reply language, which is the **requested**
/// locale rather than the one the document was found under. See [LoadedBrief].
String replyLanguageSuffix(Locale locale) => FallbackChain.filenameSuffix(locale);
