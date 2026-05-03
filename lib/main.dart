import 'package:clide/app.dart';
import 'package:clide/test_app.dart';
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
import 'package:clide/kernel/src/toolchain.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/daemon/editor_commands.dart';
import 'package:clide/src/daemon/files_commands.dart';
import 'package:clide/src/daemon/git_commands.dart';
import 'package:clide/src/daemon/pane_commands.dart';
import 'package:clide/src/daemon/pql_commands.dart';
import 'package:clide/src/editor/registry.dart' show EditorRegistry;
import 'package:clide/src/git/client.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/panes/event_sink.dart';
import 'package:clide/src/panes/registry.dart';
import 'package:clide/src/pql/client.dart';
import 'package:clide/kernel/src/syntax/tree_sitter_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Test mode: skip the full app, run the test harness instead.
  const testMode = String.fromEnvironment('CLIDE_TESTMODE');
  if (testMode.isNotEmpty) {
    runApp(const ClideTestApp());
    return;
  }

  binding.ensureSemantics();

  TreeSitterLib.init();

  final appDir = await _resolveAppDir();
  final themes = await _loadBundledThemes();

  // Resolve toolchain + boot daemon inline — same as Linux.
  // With proper signing (Developer ID), no sandbox or isolate needed.
  final toolchain = Toolchain();
  if (!kIsWeb) {
    const workspace = String.fromEnvironment('CLIDE_PROJECT');
    final root = workspace.isNotEmpty ? workspace : Directory.current.path;
    toolchain.applyResolved(resolveToolchainPaths(root));
  }

  InProcessClient? ipcClient;
  DaemonBus? daemonBus;

  DaemonDispatcher _buildDispatcher(DaemonBus events, Toolchain tc, Directory workRoot) {
    final dispatcher = DaemonDispatcher();
    final eventSink = _BusEventSink(events);
    final paneRegistry = PaneRegistry(events: eventSink);
    registerPaneCommands(dispatcher, paneRegistry);
    final filesService = FilesService(root: workRoot, events: eventSink);
    registerFilesCommands(dispatcher, filesService);
    final editorRegistry = EditorRegistry(events: eventSink, workspaceRoot: workRoot);
    registerEditorCommands(dispatcher, editorRegistry);
    final gitClient = GitClient(toolchain: tc, workDir: workRoot);
    registerGitCommands(dispatcher, gitClient, eventSink);
    final pql = PqlClient(workDir: workRoot, toolchain: tc);
    registerPqlCommands(dispatcher, pql);
    return dispatcher;
  }

  final services = await KernelServices.boot(
    appDir: appDir,
    bundledThemes: themes,
    i18nLoader: AssetCatalogLoader(bundle: rootBundle),
    preloadNamespaces: _tier0Namespaces,
    autoStartDaemonClient: false,
    toolchain: toolchain,
    daemonClientFactory: kIsWeb
        ? null
        : (log, events) {
            daemonBus = events;
            final workRoot = FilesService.atCwd(events: _BusEventSink(events)).root;
            final dispatcher = _buildDispatcher(events, toolchain, workRoot);
            ipcClient = InProcessClient(log: log, events: events, dispatcher: dispatcher);
            return ipcClient!;
          },
    onProjectOpen: kIsWeb
        ? null
        : (path) async {
            if (ipcClient == null || daemonBus == null) return;
            ipcClient!.dispatcher = _buildDispatcher(daemonBus!, toolchain, Directory(path));
          },
  );

  // Register every built-in. Tier 0 activates only the four that do
  // real work; the rest compile in as stubs so the extensions-ui can
  // list them when Tier 6 lands.
  // Registration order = default icon rail order (left to right).
  // User can override via project.layout.sidebar.order in settings.
  services.extensions
    ..register(DefaultLayoutExtension())
    ..register(WelcomeExtension())
    ..register(IpcStatusExtension())
    ..register(ThemePickerExtension())
    // Sidebar: tickets first, then decisions, files, git, pql, problems
    ..register(TicketsExtension())
    ..register(DecisionsExtension())
    ..register(FilesExtension())
    ..register(GitExtension())
    ..register(PqlExtension())
    ..register(ProblemsExtension())
    // Workspace
    ..register(ClaudeExtension())
    ..register(TerminalExtension())
    ..register(EditorExtension())
    ..register(DiffExtension())
    // Format engines + stubs
    ..register(GrammarsCoreExtension())
    ..register(MarkdownExtension())
    ..register(TodosExtension())
    ..register(CanvasExtension())
    ..register(GraphExtension())
    // UI extensions
    ..register(SettingsUiExtension())
    ..register(ExtensionsUiExtension())
    ..register(KeybindingsUiExtension())
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

class _BusEventSink implements DaemonEventSink {
  _BusEventSink(this._bus);
  final DaemonBus _bus;

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

/// Resolve the app-settings directory.
///
/// On web we don't touch the filesystem — hand back a sentinel dir so
/// `SettingsStore.load()` silently no-ops (its read-file helper returns
/// `{}` when the file doesn't exist).
Future<Directory> _resolveAppDir() async {
  if (kIsWeb) return Directory('/clide-web-no-disk');
  final home = Platform.environment['HOME'] ?? '/tmp';
  final String base;
  if (Platform.isMacOS) {
    base = '$home/Library/Application Support';
  } else {
    base = Platform.environment['XDG_CONFIG_HOME'] ?? '$home/.config';
  }
  final dir = Directory('$base/clide');
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
