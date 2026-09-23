/// Tests for the three CatalogLoader implementations in
/// `lib/kernel/src/i18n/catalog_loader.dart`. AssetCatalogLoader is
/// exercised via an in-memory AssetBundle; FileCatalogLoader via a
/// tempdir; InMemoryCatalogLoader inline.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:clide/kernel/src/i18n/catalog_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:test/test.dart';

class _MapAssetBundle extends CachingAssetBundle {
  _MapAssetBundle(this._files);
  final Map<String, String> _files;

  @override
  Future<ByteData> load(String key) async {
    final v = _files[key];
    if (v == null) throw FlutterError('asset not found: $key');
    final bytes = utf8.encode(v);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

/// A bundle that ships an `AssetManifest.bin` listing [catalogs], and records
/// every key it is asked to load.
class _ManifestBundle extends CachingAssetBundle {
  _ManifestBundle(this.catalogs);
  final Map<String, String> catalogs;
  final fetched = <String>[];

  @override
  Future<ByteData> load(String key) async {
    fetched.add(key);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final k in catalogs.keys)
          k: [
            {'asset': k},
          ],
      })!;
    }
    final v = catalogs[key];
    if (v == null) throw FlutterError('asset not found: $key');
    return ByteData.view(Uint8List.fromList(utf8.encode(v)).buffer);
  }
}

void main() {
  // The fallback chain asks for `en` before the shipped `en_us`. On web each
  // such ask was a fetch that 404'd, per namespace, on every boot (T-577).
  group('AssetCatalogLoader with an asset manifest (T-577)', () {
    test('a catalog the manifest lacks is skipped without fetching it', () async {
      final bundle = _ManifestBundle({'assets/i18n/en_us/welcome.json': '{"title":{"translation":"Hi"}}'});
      final loader = AssetCatalogLoader(bundle: bundle);
      expect(await loader.load('welcome', const Locale('en')), isEmpty);
      expect(bundle.fetched, isNot(contains('assets/i18n/en/welcome.json')));
    });

    test('a catalog the manifest lists still loads', () async {
      final bundle = _ManifestBundle({'assets/i18n/en_us/welcome.json': '{"title":{"translation":"Hi"}}'});
      final loader = AssetCatalogLoader(bundle: bundle);
      expect(await loader.load('welcome', const Locale('en', 'US')), contains('title'));
    });
  });

  group('AssetCatalogLoader', () {
    test('returns parsed JSON for a present asset', () async {
      final bundle = _MapAssetBundle({'assets/i18n/en_us/welcome.json': '{"title":{"translation":"Hi"}}'});
      final loader = AssetCatalogLoader(bundle: bundle);
      final r = await loader.load('welcome', const Locale('en', 'US'));
      expect(r['title'], isA<Map>());
    });

    test('returns an empty map when the asset is missing (FlutterError catch)', () async {
      final loader = AssetCatalogLoader(bundle: _MapAssetBundle(const {}));
      final r = await loader.load('nope', const Locale('en', 'US'));
      expect(r, isEmpty);
    });

    test('returns an empty map on malformed JSON (FormatException catch)', () async {
      final bundle = _MapAssetBundle({'assets/i18n/en_us/welcome.json': 'not json at all'});
      final loader = AssetCatalogLoader(bundle: bundle);
      expect(await loader.load('welcome', const Locale('en', 'US')), isEmpty);
    });

    test('returns an empty map when the asset is blank', () async {
      final bundle = _MapAssetBundle({'assets/i18n/en_us/welcome.json': '   \n'});
      final loader = AssetCatalogLoader(bundle: bundle);
      expect(await loader.load('welcome', const Locale('en', 'US')), isEmpty);
    });

    test('returns an empty map when JSON parses to a non-object', () async {
      final bundle = _MapAssetBundle({'assets/i18n/en_us/welcome.json': '[1, 2, 3]'});
      final loader = AssetCatalogLoader(bundle: bundle);
      expect(await loader.load('welcome', const Locale('en', 'US')), isEmpty);
    });
  });

  group('FileCatalogLoader', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clide-catalog-');
      // Catalogs live under a per-locale subdir (<root>/<locale>/<ns>.json).
      await Directory('${tmp.path}/en_us').create();
    });

    tearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    test('reads and parses a present file', () async {
      await File('${tmp.path}/en_us/welcome.json').writeAsString('{"k":{"translation":"v"}}');
      final loader = FileCatalogLoader(rootDir: tmp);
      final r = await loader.load('welcome', const Locale('en', 'US'));
      expect(r['k'], isA<Map>());
    });

    test('returns an empty map when the file is missing', () async {
      final loader = FileCatalogLoader(rootDir: tmp);
      expect(await loader.load('nope', const Locale('en', 'US')), isEmpty);
    });

    test('returns an empty map on malformed JSON (FormatException catch)', () async {
      await File('${tmp.path}/en_us/welcome.json').writeAsString('garbage');
      final loader = FileCatalogLoader(rootDir: tmp);
      expect(await loader.load('welcome', const Locale('en', 'US')), isEmpty);
    });

    test('returns an empty map when the file is blank', () async {
      await File('${tmp.path}/en_us/welcome.json').writeAsString('   ');
      final loader = FileCatalogLoader(rootDir: tmp);
      expect(await loader.load('welcome', const Locale('en', 'US')), isEmpty);
    });
  });

  group('InMemoryCatalogLoader', () {
    test('returns the catalog when (namespace, locale) matches', () async {
      final loader = InMemoryCatalogLoader({
        'welcome': {
          const Locale('en', 'US'): const {'k': 'v'},
        },
      });
      final r = await loader.load('welcome', const Locale('en', 'US'));
      expect(r['k'], 'v');
    });

    test('returns an empty map when namespace is missing', () async {
      final loader = InMemoryCatalogLoader(const {});
      expect(await loader.load('nope', const Locale('en', 'US')), isEmpty);
    });
  });
}
