import 'dart:io';

import 'package:clide/kernel/src/theme/palette.dart';
import 'package:clide/kernel/src/theme/semantic.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class ThemeDefinition {
  const ThemeDefinition({
    required this.name,
    required this.displayName,
    required this.dark,
    required this.palette,
    this.semanticOverride,
    this.surfaceOverride,
    this.extensionOverride,
  });

  final String name;
  final String displayName;
  final bool dark;
  final Palette palette;
  final SemanticRoles? semanticOverride;
  final Map<String, String>? surfaceOverride;
  final Map<String, String>? extensionOverride;
}

class ThemeLoader {
  const ThemeLoader();

  ThemeDefinition fromYamlString(String text, {String? fallbackName}) {
    final doc = loadYaml(text);
    if (doc is! Map) {
      throw FormatException('Theme root is not a map');
    }
    final name = (doc['name'] as String?) ?? fallbackName;
    if (name == null || name.isEmpty) {
      throw const FormatException('Theme missing `name`');
    }
    final displayName = (doc['display_name'] as String?) ?? name;
    final dark = (doc['dark'] as bool?) ?? true;

    final paletteYaml = doc['palette'];
    if (paletteYaml is! Map) {
      throw const FormatException('Theme missing `palette`');
    }
    final palette = _parsePalette(paletteYaml);

    // Syntax colours inject into the surface override layer so
    // TokenKeys.syntax* resolve directly from the theme YAML.
    final syntaxYaml = doc['syntax'];
    final syntaxSurface = <String, String>{};
    if (syntaxYaml is Map) {
      const syntaxMap = {
        'keyword': 'syntax.keyword',
        'type': 'syntax.type',
        'string': 'syntax.string',
        'number': 'syntax.number',
        'comment': 'syntax.comment',
        'method': 'syntax.method',
        'punct': 'syntax.punct',
      };
      syntaxYaml.forEach((k, v) {
        final key = syntaxMap['$k'];
        if (key != null && v is String) syntaxSurface[key] = v;
      });
    }

    final semantic = doc['semantic'];
    final surface = doc['surface'];
    final extension = doc['extension'];

    final mergedSurface = <String, String>{
      ...syntaxSurface,
      if (surface is Map) ..._parseRefMap(surface),
    };

    return ThemeDefinition(
      name: name,
      displayName: displayName,
      dark: dark,
      palette: palette,
      semanticOverride:
          semantic is Map ? _parseSemantic(semantic, palette) : null,
      surfaceOverride: mergedSurface.isNotEmpty ? mergedSurface : null,
      extensionOverride: extension is Map ? _parseRefMap(extension) : null,
    );
  }

  Future<ThemeDefinition> fromAsset(
      AssetBundle bundle, String assetPath) async {
    final txt = await bundle.loadString(assetPath);
    final fallback = assetPath.split('/').last.replaceAll('.yaml', '');
    return fromYamlString(txt, fallbackName: fallback);
  }

  Future<ThemeDefinition> fromFile(File f) async {
    final txt = await f.readAsString();
    final fallback = f.uri.pathSegments.last.replaceAll('.yaml', '');
    return fromYamlString(txt, fallbackName: fallback);
  }
}

Palette _parsePalette(Map src) {
  final colors = <String, Color>{};
  src.forEach((k, v) {
    if (v is! String) return;
    final c = Palette.parseHex(v);
    if (c != null) colors['$k'] = c;
  });
  return Palette(colors);
}

SemanticRoles _parseSemantic(Map src, Palette palette) {
  final roles = <String, Color>{};
  src.forEach((k, v) {
    if (v is! String) return;
    final resolved =
        v.startsWith('#') ? Palette.parseHex(v) : palette.lookup(v);
    if (resolved != null) roles['$k'] = resolved;
  });
  return SemanticRoles(roles);
}

Map<String, String> _parseRefMap(Map src) {
  final out = <String, String>{};
  src.forEach((k, v) {
    if (v is String) out['$k'] = v;
  });
  return out;
}
