import 'package:clide_app/extension/extension.dart';

/// Tier-0 stub. The real adapter wraps a parsed Lua extension manifest
/// and a handle to the Lua state; contributions are proxied to
/// callbacks registered by `clide.contribute(...)` from the Lua side.
class LuaExtension extends ClideExtension {
  LuaExtension({
    required this.id,
    required this.title,
    required this.version,
    this.dependsOn = const [],
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String version;
  @override
  final List<String> dependsOn;

  @override
  List<ContributionPoint> get contributions => const [];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    throw UnsupportedError('Lua runtime lands at Tier 6.');
  }
}
