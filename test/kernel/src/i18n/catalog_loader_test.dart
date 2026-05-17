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

void main() {
  group('AssetCatalogLoader', () {
    test('returns parsed JSON for a present asset', () async {
      final bundle = _MapAssetBundle({
        'lib/kernel/src/i18n/catalog/welcome_en_us.json': '{"title":{"translation":"Hi"}}',
      });
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
      final bundle = _MapAssetBundle({
        'lib/kernel/src/i18n/catalog/welcome_en_us.json': 'not json at all',
      });
      final loader = AssetCatalogLoader(bundle: bundle);
      expect(await loader.load('welcome', const Locale('en', 'US')), isEmpty);
    });

    test('returns an empty map when the asset is blank', () async {
      final bundle = _MapAssetBundle({
        'lib/kernel/src/i18n/catalog/welcome_en_us.json': '   \n',
      });
      final loader = AssetCatalogLoader(bundle: bundle);
      expect(await loader.load('welcome', const Locale('en', 'US')), isEmpty);
    });

    test('returns an empty map when JSON parses to a non-object', () async {
      final bundle = _MapAssetBundle({
        'lib/kernel/src/i18n/catalog/welcome_en_us.json': '[1, 2, 3]',
      });
      final loader = AssetCatalogLoader(bundle: bundle);
      expect(await loader.load('welcome', const Locale('en', 'US')), isEmpty);
    });
  });

  group('FileCatalogLoader', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clide-catalog-');
    });

    tearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    test('reads and parses a present file', () async {
      await File('${tmp.path}/welcome_en_us.json').writeAsString('{"k":{"translation":"v"}}');
      final loader = FileCatalogLoader(rootDir: tmp);
      final r = await loader.load('welcome', const Locale('en', 'US'));
      expect(r['k'], isA<Map>());
    });

    test('returns an empty map when the file is missing', () async {
      final loader = FileCatalogLoader(rootDir: tmp);
      expect(await loader.load('nope', const Locale('en', 'US')), isEmpty);
    });

    test('returns an empty map on malformed JSON (FormatException catch)', () async {
      await File('${tmp.path}/welcome_en_us.json').writeAsString('garbage');
      final loader = FileCatalogLoader(rootDir: tmp);
      expect(await loader.load('welcome', const Locale('en', 'US')), isEmpty);
    });

    test('returns an empty map when the file is blank', () async {
      await File('${tmp.path}/welcome_en_us.json').writeAsString('   ');
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
