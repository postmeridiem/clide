import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Resolves the ordered list of locales to try when looking up a key.
///
/// Order, starting from the current locale:
///   1. exact (language + country)      — e.g. nl_NL
///   2. language-only                    — e.g. nl
///   3. default language + country       — e.g. en_US
///   4. default language-only            — e.g. en
///
/// Duplicates are removed while preserving order. `null` country code is
/// canonicalized by omitting it (not empty string) so equality works.
@immutable
class FallbackChain {
  const FallbackChain({
    required this.current,
    required this.defaultLocale,
  });

  final Locale current;
  final Locale defaultLocale;

  List<Locale> resolve() {
    final out = <Locale>[];
    for (final l in [
      current,
      Locale(current.languageCode),
      defaultLocale,
      Locale(defaultLocale.languageCode),
    ]) {
      final canon = _canon(l);
      if (!out.any((e) => _canon(e) == canon)) {
        out.add(l);
      }
    }
    return out;
  }

  static String _canon(Locale l) {
    final country = l.countryCode;
    if (country == null || country.isEmpty) return l.languageCode;
    return '${l.languageCode}_$country';
  }

  /// Canonical filename suffix for a locale, matching fframe: `en_us`
  /// (lowercase, country only when present).
  static String filenameSuffix(Locale l) {
    final lang = l.languageCode.toLowerCase();
    final country = l.countryCode?.toLowerCase();
    if (country == null || country.isEmpty) return lang;
    return '${lang}_$country';
  }
}
