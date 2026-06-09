import 'dart:io';
import 'dart:ui';

import 'package:clide/kernel/kernel.dart';

import 'fake_ipc.dart';

/// Boots a [KernelServices] with in-memory defaults suitable for tests.
/// No real daemon, no real filesystem outside a temp dir, no asset
/// bundle — i18n catalogs are passed as literals.
class KernelFixture {
  KernelFixture._({required this.services, required this.ipc, required this.tempDir});

  final KernelServices services;
  final FakeDaemonClient ipc;
  final Directory tempDir;

  static Future<KernelFixture> create({
    List<ThemeDefinition>? bundledThemes,
    Map<String, Map<Locale, Map<String, Object?>>>? i18nCatalogs,
    List<String>? preloadNamespaces,
    Locale? initialLocale,
    Locale defaultLocale = const Locale('en', 'US'),
    Future<String?> Function(String path)? onValidateProject,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('clide_test_');
    final themes = bundledThemes ?? [_miniTheme()];
    final catalogs = i18nCatalogs ?? const {};
    FakeDaemonClient? fake;
    final services = await KernelServices.boot(
      appDir: tempDir,
      bundledThemes: themes,
      i18nLoader: InMemoryCatalogLoader(catalogs),
      preloadNamespaces: preloadNamespaces ?? catalogs.keys.toList(),
      defaultLocale: defaultLocale,
      initialLocale: initialLocale,
      daemonClientFactory: (log, events, _, __) {
        fake = FakeDaemonClient(log: log, events: events);
        return fake!;
      },
      autoStartDaemonClient: false,
      // Validate projects with a pure-Dart `.git` walk instead of the default
      // `git rev-parse` subprocess. A real `Process.run` under the widget-test
      // fake-async harness leaks its exit ReceivePort and wedges teardown for
      // ~10 minutes (T-280); `existsSync` opens no native port, so it's safe.
      onValidateProject: onValidateProject ?? _walkForGitRoot,
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

/// Pure-Dart stand-in for `git rev-parse --show-toplevel`: walk up from [path]
/// looking for a `.git` directory and return the repo root, or null if none.
/// Synchronous `existsSync` deliberately — it opens no native ReceivePort, so
/// it completes cleanly under the fake-async widget-test harness where a real
/// `Process.run` would leak and hang teardown (T-280).
Future<String?> _walkForGitRoot(String path) {
  var dir = Directory(path);
  if (!dir.existsSync()) return Future.value(null);
  while (true) {
    // A `.git` directory (normal clone) or file (worktree/submodule) both mark
    // a repo root — match either, like `git rev-parse` would.
    if (FileSystemEntity.typeSync('${dir.path}/.git') != FileSystemEntityType.notFound) {
      return Future.value(dir.path);
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return Future.value(null); // reached the fs root
    dir = parent;
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
