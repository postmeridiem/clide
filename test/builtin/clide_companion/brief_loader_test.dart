import 'dart:ui' show Locale;

import 'package:clide/builtin/clide_companion/src/prompt/brief_loader.dart';
import 'package:clide/builtin/clide_companion/src/prompt/companion_prompt.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A bundle holding only the assets it was given, so a miss is a real miss.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final v = files[key];
    if (v == null) throw FlutterError('missing asset: $key');
    final bytes = Uint8List.fromList(v.codeUnits);
    return ByteData.view(bytes.buffer);
  }
}

/// T-532 — the brief is a locale-routed document, not catalog keys. These pin
/// the behaviour that choice buys, and the one place it deliberately diverges.
void main() {
  const en = 'en_us brief {about} {language} {faces}';
  const nl = 'nl_nl brief {about} {language} {faces}';

  test('an exact locale match wins', () async {
    final b = _Bundle({'$kPromptRoot/nl_nl/$kBriefAsset': nl, '$kPromptRoot/en_us/$kBriefAsset': en});
    final got = await loadCompanionBrief(locale: const Locale('nl', 'NL'), bundle: b);
    expect(got!.text, nl);
    expect(got.foundIn, 'nl_nl');
  });

  test('a locale with no brief falls through to English rather than nothing', () async {
    // The reason this is a document and not a catalog key: a missing key fails
    // the parity test, a missing document simply falls back.
    final b = _Bundle({'$kPromptRoot/en_us/$kBriefAsset': en});
    final got = await loadCompanionBrief(locale: const Locale('nl', 'NL'), bundle: b);
    expect(got!.text, en);
    expect(got.foundIn, 'en_us');
  });

  test('a fallback is total — he speaks the brief he got, and never mentions the miss', () async {
    // An earlier draft loaded the English brief and still instructed "reply in
    // Dutch", so that adding a locale could not silently change his language.
    // Dropped: an English document asking for Dutch is a mixed signal at exactly
    // the moment his register is being set, and the miss is a packaging gap
    // rather than anything a companion should surface.
    final b = _Bundle({'$kPromptRoot/en_us/$kBriefAsset': en});
    final got = await loadCompanionBrief(locale: const Locale('nl', 'NL'), bundle: b);
    final prompt = composeSystemPrompt(brief: got!.text, localeSuffix: got.foundIn);

    expect(prompt, contains('English'));
    expect(prompt, isNot(contains('Dutch')));
    expect(prompt.toLowerCase(), isNot(contains('fallback')));
    expect(prompt.toLowerCase(), isNot(contains('unavailable')));
  });

  test('no brief at all is null, not an empty prompt', () async {
    // A session spawned with an empty brief is a generic assistant wearing
    // Clide's face, which is worse than no companion.
    expect(await loadCompanionBrief(locale: const Locale('en', 'US'), bundle: _Bundle({})), isNull);
  });

  test('an empty document is treated as absent', () async {
    final b = _Bundle({'$kPromptRoot/nl_nl/$kBriefAsset': '   \n', '$kPromptRoot/en_us/$kBriefAsset': en});
    final got = await loadCompanionBrief(locale: const Locale('nl', 'NL'), bundle: b);
    expect(got!.foundIn, 'en_us');
  });

  test('the shipped brief exists and has every placeholder', () async {
    // Guards the packaging: an unbundled asset is invisible until a user runs a
    // release build and gets no companion.
    TestWidgetsFlutterBinding.ensureInitialized();
    final got = await loadCompanionBrief(locale: const Locale('en', 'US'));
    expect(got, isNotNull, reason: 'assets/clide/prompts/en_us/ must be listed in pubspec.yaml');
    expect(got!.text, contains(kAboutPlaceholder));
    expect(got.text, contains(kLanguagePlaceholder));
    expect(got.text, contains(kFacesPlaceholder));
  });
}
