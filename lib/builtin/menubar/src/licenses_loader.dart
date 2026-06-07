/// Loads the bundled `assets/licenses.yaml` manifest for the About dialog
/// (T-48 / D-42). The runtime `dependencies:` list is what the About screen
/// renders; `self:` carries clide's own license.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

class SelfEntry {
  const SelfEntry({required this.name, required this.version, required this.license});
  final String name;
  final String version;
  final String license;
}

class DepEntry {
  const DepEntry({required this.name, required this.version, required this.license});
  final String name;
  final String version;
  final String license;
}

class LicensesManifest {
  const LicensesManifest({required this.self, required this.dependencies});
  final SelfEntry self;
  final List<DepEntry> dependencies;
}

/// Parse the licenses-manifest YAML text. Pure (no asset bundle) so it's
/// directly unit-testable. Missing fields degrade to '—' rather than throwing.
LicensesManifest parseLicenses(String yamlText) {
  final doc = loadYaml(yamlText);
  final map = doc is YamlMap ? doc : const {};
  String s(Object? v) => v == null ? '—' : '$v';

  final selfRaw = map['self'];
  final selfMap = selfRaw is YamlMap ? selfRaw : const {};
  final self = SelfEntry(name: s(selfMap['name']), version: s(selfMap['version']), license: s(selfMap['license']));

  final deps = <DepEntry>[];
  final list = map['dependencies'];
  if (list is YamlList) {
    for (final e in list) {
      if (e is YamlMap) {
        deps.add(DepEntry(name: s(e['name']), version: s(e['version']), license: s(e['license'])));
      }
    }
  }
  return LicensesManifest(self: self, dependencies: deps);
}

LicensesManifest? _cache;

/// Load + parse the bundled manifest, cached after the first read.
Future<LicensesManifest> loadLicenses() async {
  final cached = _cache;
  if (cached != null) return cached;
  final raw = await rootBundle.loadString('assets/licenses.yaml');
  return _cache = parseLicenses(raw);
}
