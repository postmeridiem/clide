import 'dart:io';
import 'dart:ui';

import 'package:clide_app/kernel/kernel.dart';

import 'fake_ipc.dart';

/// Boots a [KernelServices] with in-memory defaults suitable for tests.
/// No real daemon, no real filesystem outside a temp dir, no asset
/// bundle — i18n catalogs are passed as literals.
class KernelFixture {
  KernelFixture._(
      {required this.services, required this.ipc, required this.tempDir});

  final KernelServices services;
  final FakeDaemonClient ipc;
  final Directory tempDir;

  static Future<KernelFixture> create({
    List<ThemeDefinition>? bundledThemes,
    Map<String, Map<Locale, Map<String, Object?>>>? i18nCatalogs,
    Locale? initialLocale,
    Locale defaultLocale = const Locale('en', 'US'),
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('clide_test_');
    final themes = bundledThemes ?? [_miniTheme()];
    final catalogs = i18nCatalogs ?? const {};
    FakeDaemonClient? fake;
    final services = await KernelServices.boot(
      appDir: tempDir,
      bundledThemes: themes,
      i18nLoader: InMemoryCatalogLoader(catalogs),
      preloadNamespaces: catalogs.keys.toList(),
      defaultLocale: defaultLocale,
      initialLocale: initialLocale,
      daemonClientFactory: (log, events) {
        fake = FakeDaemonClient(log: log, events: events);
        return fake!;
      },
      autoStartDaemonClient: false,
    );
    return KernelFixture._(
      services: services,
      ipc: fake!,
      tempDir: tempDir,
    );
  }

  Future<void> dispose() async {
    await services.dispose();
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // ignore in tests; OS will reclaim
      }
    }
  }
}

/// A minimal bundled theme for tests that don't care about specific
/// colors — just need the pipeline to resolve.
ThemeDefinition _miniTheme() {
  const palette = <String, Color>{
    'primary': Color(0xFF00A3D2),
    'accent': Color(0xFFFA5F8B),
    'background': Color(0xFF21262F),
    'surface': Color(0xFF393E48),
    'panel': Color(0xFF292E38),
    'foreground': Color(0xFFE2E8F5),
    'muted': Color(0xFF6A7280),
    'success': Color(0xFF00AB9A),
    'warning': Color(0xFFD08447),
    'error': Color(0xFFF06C6F),
    'info': Color(0xFF00A3D2),
  };
  return const ThemeDefinition(
    name: 'test',
    displayName: 'Test',
    dark: true,
    palette: Palette(palette),
  );
}
