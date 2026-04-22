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
import 'package:clide/kernel/src/ipc/in_process.dart';
import 'package:clide/kernel/src/syntax/tree_sitter_ffi.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/daemon/editor_commands.dart';
import 'package:clide/src/daemon/files_commands.dart';
import 'package:clide/src/daemon/git_commands.dart';
import 'package:clide/src/daemon/pane_commands.dart';
import 'package:clide/src/daemon/pql_commands.dart';
import 'package:clide/src/editor/registry.dart' show EditorRegistry;
import 'package:clide/src/panes/registry.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/panes/event_sink.dart';
import 'package:clide/src/pql/client.dart';
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
    autoStartDaemonClient: false,
    daemonClientFactory: kIsWeb ? null : (log, events) {
      final dispatcher = DaemonDispatcher();
      final eventSink = _BusEventSink(events);
      final filesService = FilesService.atCwd(events: eventSink);
      final workRoot = filesService.root;
      final paneRegistry = PaneRegistry(events: eventSink);
      registerPaneCommands(dispatcher, paneRegistry);
      registerFilesCommands(dispatcher, filesService);
      final editorRegistry = EditorRegistry(events: eventSink, workspaceRoot: workRoot);
      registerEditorCommands(dispatcher, editorRegistry);
      registerGitCommands(dispatcher, workRoot, eventSink);
      final pql = PqlClient(workDir: workRoot);
      registerPqlCommands(dispatcher, pql);
      return InProcessClient(log: log, events: events, dispatcher: dispatcher);
    },
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
class _BusEventSink implements DaemonEventSink {
  _BusEventSink(this._bus);
  final EventBus _bus;

  @override
  void emit(IpcEvent event) {
    _bus.emit(DaemonEvent(
      subsystem: event.subsystem,
      kind: event.kind,
      data: event.data,
      ts: DateTime.now(),
    ));
  }
}

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
