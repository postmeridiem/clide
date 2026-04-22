import 'package:clide/app.dart';
import 'package:clide/builtin/canvas/canvas.dart';
import 'package:clide/builtin/claude/claude.dart';
import 'package:clide/builtin/claude_control/claude_control.dart';
import 'package:clide/builtin/decisions/decisions.dart';
import 'package:clide/builtin/default_layout/default_layout.dart';
import 'package:clide/builtin/diff/diff.dart';
import 'package:clide/builtin/editor/editor.dart';
import 'package:clide/builtin/extensions_ui/extensions_ui.dart';
import 'package:clide/builtin/files/files.dart';
import 'package:clide/builtin/git/git.dart';
import 'package:clide/builtin/grammars_core/grammars_core.dart';
import 'package:clide/builtin/graph/graph.dart';
import 'package:clide/builtin/ipc_status/ipc_status.dart';
import 'package:clide/builtin/keybindings_ui/keybindings_ui.dart';
import 'package:clide/builtin/markdown/markdown.dart';
import 'package:clide/builtin/pql/pql.dart';
import 'package:clide/builtin/problems/problems.dart';
import 'package:clide/builtin/settings_ui/settings_ui.dart';
import 'package:clide/builtin/terminal/terminal.dart';
import 'package:clide/builtin/theme_picker/theme_picker.dart';
import 'package:clide/builtin/tickets/tickets.dart';
import 'package:clide/builtin/todos/todos.dart';
import 'package:clide/builtin/welcome/welcome.dart';
import 'dart:io' show Directory, Platform;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/syntax/tree_sitter_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  binding.ensureSemantics();

  TreeSitterLib.init();

  final appDir = await _resolveAppDir();
  final themes = await _loadBundledThemes();

  final services = await KernelServices.boot(
    appDir: appDir,
    bundledThemes: themes,
    i18nLoader: AssetCatalogLoader(bundle: rootBundle),
    preloadNamespaces: _tier0Namespaces,
    // The local unix-socket daemon is desktop-only. On web the
    // connection indicator stays `disconnected` — that's the honest
    // state: the Flutter-web build can't reach a local socket.
    autoStartDaemonClient: !kIsWeb,
    socketPath: kIsWeb ? '/clide-web-no-socket' : null,
  );

  // Register every built-in. Tier 0 activates only the four that do
  // real work; the rest compile in as stubs so the extensions-ui can
  // list them when Tier 6 lands.
  services.extensions
    ..register(DefaultLayoutExtension())
    ..register(WelcomeExtension())
    ..register(IpcStatusExtension())
    ..register(ThemePickerExtension())
    ..register(ClaudeExtension())
    ..register(TerminalExtension())
    ..register(FilesExtension())
    ..register(EditorExtension())
    ..register(GrammarsCoreExtension())
    ..register(MarkdownExtension())
    ..register(DiffExtension())
    ..register(GitExtension())
    ..register(PqlExtension())
    ..register(TodosExtension())
    ..register(ProblemsExtension())
    ..register(CanvasExtension())
    ..register(GraphExtension())
    ..register(SettingsUiExtension())
    ..register(ExtensionsUiExtension())
    ..register(KeybindingsUiExtension())
    ..register(DecisionsExtension())
    ..register(TicketsExtension())
    ..register(ClaudeControlExtension());

  await services.extensions.activateAll();

  if (!kIsWeb) {
    await services.project.loadRecents();
    var opened = await services.project.openLast();
    if (!opened) {
      opened = await services.project.open(Directory.current.path);
    }
    if (opened) {
      services.panels.activateTab(Slots.workspace, 'claude.primary');
    }
  }

  runApp(ClideApp(services: services));
}

/// Resolve the app-settings directory.
///
/// On web we don't touch the filesystem — hand back a sentinel dir so
/// `SettingsStore.load()` silently no-ops (its read-file helper returns
/// `{}` when the file doesn't exist).
Future<Directory> _resolveAppDir() async {
  if (kIsWeb) return Directory('/clide-web-no-disk');
  final home = Platform.environment['HOME'] ?? '/tmp';
  final xdg = Platform.environment['XDG_CONFIG_HOME'] ?? '$home/.config';
  final dir = Directory('$xdg/clide');
  await dir.create(recursive: true);
  return dir;
}

Future<List<ThemeDefinition>> _loadBundledThemes() async {
  const loader = ThemeLoader();
  const paths = [
    'lib/kernel/src/theme/themes/clide.yaml',
    'lib/kernel/src/theme/themes/midnight.yaml',
    'lib/kernel/src/theme/themes/paper.yaml',
    'lib/kernel/src/theme/themes/terminal.yaml',
  ];
  final out = <ThemeDefinition>[];
  for (final p in paths) {
    out.add(await loader.fromAsset(rootBundle, p));
  }
  return out;
}

/// Every Tier-0 extension that ships an i18n catalog. Extensions
/// registered but not active (the 17 stubs) don't preload — their
/// catalogs load lazily on activate in later tiers.
const List<String> _tier0Namespaces = [
  'builtin.default-layout',
  'builtin.welcome',
  'builtin.ipc-status',
  'builtin.theme-picker',
  'builtin.terminal',
  'builtin.files',
  'builtin.claude',
  'builtin.editor',
];
