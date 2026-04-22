import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:clide/kernel/src/i18n/fallback_chain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads catalog JSON for a given `(namespace, locale)` pair.
///
/// The file format (mirrors fframe verbatim):
///   `{namespace}_{lang}_{country}.json`  — or `{namespace}_{lang}.json`
///   Content: `{ "key": { "translation": "...", ...extras }, ... }`.
///
/// Two reader shapes:
///   * Asset bundle (built-in catalogs shipped under `lib/kernel/src/i18n/catalog/`).
///   * Filesystem (third-party extensions under `~/.clide/extensions/<id>/`).
///
/// Missing files return an empty map — not an error. The fallback chain
/// walker handles "nothing for this locale" by trying the next one.
abstract class CatalogLoader {
  Future<Map<String, Object?>> load(String namespace, Locale locale);
}

class AssetCatalogLoader implements CatalogLoader {
  AssetCatalogLoader({required this.bundle, this.rootDir = _defaultRoot});

  final AssetBundle bundle;
  final String rootDir;

  static const String _defaultRoot = 'lib/kernel/src/i18n/catalog';

  @override
  Future<Map<String, Object?>> load(String namespace, Locale locale) async {
    final suffix = FallbackChain.filenameSuffix(locale);
    final path = '$rootDir/${namespace}_$suffix.json';
    try {
      final text = await bundle.loadString(path);
      if (text.trim().isEmpty) return const {};
      final obj = jsonDecode(text);
      if (obj is Map) return obj.cast<String, Object?>();
      return const {};
    } on FlutterError {
      // Asset missing. Return empty map; fallback chain handles the miss.
      return const {};
    } on FormatException {
      return const {};
    }
  }
}

class FileCatalogLoader implements CatalogLoader {
  const FileCatalogLoader({required this.rootDir});

  final Directory rootDir;

  @override
  Future<Map<String, Object?>> load(String namespace, Locale locale) async {
    final suffix = FallbackChain.filenameSuffix(locale);
    final f = File('${rootDir.path}/${namespace}_$suffix.json');
    if (!await f.exists()) return const {};
    try {
      final text = await f.readAsString();
      if (text.trim().isEmpty) return const {};
      final obj = jsonDecode(text);
      if (obj is Map) return obj.cast<String, Object?>();
    } on FormatException {
      // malformed — return empty; caller will fall back.
    }
    return const {};
  }
}

/// Preloaded-in-memory loader for tests and synthesized catalogs.
class InMemoryCatalogLoader implements CatalogLoader {
  InMemoryCatalogLoader(this._map);

  final Map<String, Map<Locale, Map<String, Object?>>> _map;

  @override
  Future<Map<String, Object?>> load(String namespace, Locale locale) async {
    final byNs = _map[namespace];
    if (byNs == null) return const {};
    // match by canonical comparison so Locale("en") == registered Locale("en")
    for (final entry in byNs.entries) {
      if (_eq(entry.key, locale)) return entry.value;
    }
    return const {};
  }

  static bool _eq(Locale a, Locale b) =>
      a.languageCode == b.languageCode && a.countryCode == b.countryCode;
}
