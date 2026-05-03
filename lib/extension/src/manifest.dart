import 'dart:io';

import 'package:yaml/yaml.dart';

/// A parsed third-party extension manifest.
///
/// Built-in extensions don't need a manifest file — they compile in as
/// Dart subclasses of [ClideExtension]. Third-party extensions ship a
/// `manifest.yaml` under `~/.clide/extensions/<id>/` alongside their
/// Lua entrypoint; this class parses and validates that file.
class ExtensionManifest {
  const ExtensionManifest({
    required this.id,
    required this.title,
    required this.version,
    required this.dependsOn,
    required this.entry,
    required this.schemaVersion,
  });

  final String id;
  final String title;
  final String version;
  final List<String> dependsOn;
  final String entry; // relative path to lua entrypoint
  final int schemaVersion;

  factory ExtensionManifest.fromYamlString(String text) {
    final doc = loadYaml(text);
    if (doc is! Map) {
      throw const FormatException('manifest root is not a map');
    }
    final id = doc['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('manifest missing `id`');
    }
    final title = (doc['title'] as String?) ?? id;
    final version = (doc['version'] as String?) ?? '0.0.0';
    final entry = (doc['entry'] as String?) ?? 'extension.lua';
    final schemaVersion = (doc['schema_version'] as int?) ?? 1;
    final depsYaml = doc['depends_on'];
    final deps = <String>[];
    if (depsYaml is YamlList) {
      for (final d in depsYaml) {
        if (d is String) deps.add(d);
      }
    }
    return ExtensionManifest(
      id: id,
      title: title,
      version: version,
      dependsOn: deps,
      entry: entry,
      schemaVersion: schemaVersion,
    );
  }

  static Future<ExtensionManifest> fromFile(File f) async => ExtensionManifest.fromYamlString(await f.readAsString());
}
