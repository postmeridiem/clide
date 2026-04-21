import 'dart:io';

import 'package:clide_app/extension/src/manifest.dart';

/// Scans the third-party extensions root for `manifest.yaml` files.
///
/// Built-ins are registered by the app at boot; this scanner handles
/// installed third-party extensions. Tier 0 returns an empty list
/// until the Lua adapter lands — every call is safe to make anyway.
class ExtensionScanner {
  const ExtensionScanner();

  /// Typical install root: `~/.clide/extensions/<id>/manifest.yaml`.
  /// Override for tests.
  Directory defaultRoot() {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return Directory('$home/.clide/extensions');
  }

  Future<List<ExtensionManifest>> discover({Directory? root}) async {
    final dir = root ?? defaultRoot();
    if (!await dir.exists()) return const [];
    final out = <ExtensionManifest>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final m = File('${entity.path}/manifest.yaml');
      if (!await m.exists()) continue;
      try {
        out.add(await ExtensionManifest.fromFile(m));
      } on FormatException catch (_) {
        // skip malformed manifests; the extensions-ui will surface them
      }
    }
    return out;
  }
}
