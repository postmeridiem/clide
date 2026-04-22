import 'dart:ui';

import 'package:clide/kernel/src/i18n/catalog_loader.dart';
import 'package:clide/kernel/src/i18n/fallback_chain.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:flutter/foundation.dart';

@immutable
class I18nReplacer {
  const I18nReplacer({required this.from, required this.replace});
  final String from;
  final String replace;
}

/// Text-driven i18n — fframe-style. Keys are strings, lookups are by
/// `(namespace, key)`, missing keys fall back through a locale chain
/// and finally to the caller-supplied placeholder.
///
/// Singleton-per-kernel: `kernel.i18n`. Extensions write:
///   final t = ctx.i18n;
///   t.string('key', placeholder: '...', namespace: ext.id);
class I18n extends ChangeNotifier {
  I18n({
    required this.loader,
    required this.log,
    required Locale defaultLocale,
    Locale? initialLocale,
    List<Locale> availableLocales = const [Locale('en', 'US')],
  })  : _defaultLocale = defaultLocale,
        _current = initialLocale ?? defaultLocale,
        _available = List<Locale>.unmodifiable(availableLocales);

  final CatalogLoader loader;
  final Logger log;

  final Locale _defaultLocale;
  Locale _current;
  final List<Locale> _available;

  /// namespace -> locale -> flat key map
  final Map<String, Map<Locale, Map<String, Object?>>> _cache = {};

  /// Keys we've already warned about for a given (namespace, key, locale).
  /// Keeps the log quiet across repeated lookups.
  final Set<String> _warnedMisses = {};

  Locale get currentLocale => _current;
  Locale get defaultLocale => _defaultLocale;
  List<Locale> get availableLocales => _available;

  /// Register a catalog that was loaded outside of [loader] — e.g. by the
  /// ExtensionManager when a third-party extension activates.
  void registerCatalog(
    String namespace,
    Locale locale,
    Map<String, Object?> catalog,
  ) {
    _cache.putIfAbsent(
        namespace, () => <Locale, Map<String, Object?>>{})[locale] = catalog;
    notifyListeners();
  }

  /// Remove every entry for a namespace (extension deactivated).
  void unregisterCatalog(String namespace) {
    if (_cache.remove(namespace) != null) {
      notifyListeners();
    }
  }

  /// Set the current locale and reload every already-cached namespace
  /// for the new chain. Listeners fire once at the end.
  Future<void> setLocale(Locale locale) async {
    if (locale == _current) return;
    _current = locale;
    _warnedMisses.clear();
    for (final ns in _cache.keys.toList()) {
      await _ensureLoaded(ns);
    }
    notifyListeners();
  }

  /// Eagerly load a namespace across the whole fallback chain. Safe to
  /// call more than once (subsequent calls only fill missing locales).
  Future<void> ensureNamespaceLoaded(String namespace) async {
    await _ensureLoaded(namespace);
  }

  Future<void> _ensureLoaded(String namespace) async {
    final byLocale = _cache.putIfAbsent(
      namespace,
      () => <Locale, Map<String, Object?>>{},
    );
    final chain = FallbackChain(
      current: _current,
      defaultLocale: _defaultLocale,
    ).resolve();
    for (final l in chain) {
      if (byLocale.containsKey(l)) continue;
      byLocale[l] = await loader.load(namespace, l);
    }
  }

  /// Look up a key, walking the locale fallback chain. Returns the
  /// placeholder if nothing hits; returns the key itself when placeholder
  /// is null (developer fallback — keys are more useful than blanks).
  String string(
    String key, {
    required String namespace,
    String? placeholder,
  }) {
    final byLocale = _cache[namespace];
    if (byLocale == null) {
      _warnOnce(
        '$namespace::MISSING_NAMESPACE::$key',
        'i18n: namespace not registered: $namespace (key: $key)',
      );
      return placeholder ?? key;
    }

    final chain = FallbackChain(
      current: _current,
      defaultLocale: _defaultLocale,
    ).resolve();

    for (final locale in chain) {
      final catalog = byLocale[locale];
      if (catalog == null) continue;
      final hit = _extract(catalog, key);
      if (hit != null) return hit;
    }

    _warnOnce(
      '$namespace::${_current.languageCode}::$key',
      'i18n: missing key "$key" in namespace "$namespace" (locale ${_current.toString()})',
    );
    return placeholder ?? key;
  }

  /// [string] + naive `replaceAll` interpolation per replacer.
  /// Matches fframe: replacers whose [from] isn't present are silent no-ops.
  String interpolated(
    String key, {
    required String namespace,
    String? placeholder,
    List<I18nReplacer> replacers = const [],
  }) {
    var out = string(key, namespace: namespace, placeholder: placeholder);
    for (final r in replacers) {
      out = out.replaceAll(r.from, r.replace);
    }
    return out;
  }

  /// Walks fframe's nested shape: `{ "translation": "..." }`. If the
  /// value is a plain string we accept that too (forward-compat).
  String? _extract(Map<String, Object?> catalog, String key) {
    final v = catalog[key];
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map && v['translation'] is String) {
      return v['translation'] as String;
    }
    return null;
  }

  void _warnOnce(String dedupeKey, String message) {
    if (_warnedMisses.add(dedupeKey)) {
      log.warn('i18n', message);
    }
  }
}
