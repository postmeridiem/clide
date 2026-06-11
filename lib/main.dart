import 'dart:async';

import 'package:clide/app.dart';
import 'package:clide/test_app.dart';
import 'package:clide/builtin/canvas/canvas.dart';
import 'package:clide/builtin/claude/claude.dart';
import 'package:clide/builtin/claude_control/claude_control.dart';
import 'package:clide/builtin/cli_install/cli_install.dart';
import 'package:clide/builtin/decisions/decisions.dart';
import 'package:clide/builtin/deeplink/deeplink.dart';
import 'package:clide/builtin/default_layout/default_layout.dart';
import 'package:clide/builtin/diff/diff.dart';
import 'package:clide/builtin/editor/editor.dart';
import 'package:clide/builtin/extensions_ui/extensions_ui.dart';
import 'package:clide/builtin/files/files.dart';
import 'package:clide/builtin/git/git.dart';
import 'package:clide/builtin/search/search.dart';
import 'package:clide/builtin/grammars_core/grammars_core.dart';
import 'package:clide/builtin/graph/graph.dart';
import 'package:clide/builtin/menubar/menubar.dart';
import 'package:clide/builtin/output/output.dart';
import 'package:clide/builtin/keybindings_ui/keybindings_ui.dart';
import 'package:clide/builtin/markdown/markdown.dart';
import 'package:clide/builtin/pql/pql.dart';
import 'package:clide/builtin/problems/problems.dart';
import 'package:clide/builtin/settings_ui/settings_ui.dart';
import 'package:clide/builtin/terminal/terminal.dart';
import 'package:clide/builtin/theme_picker/theme_picker.dart';
import 'package:clide/builtin/view/view.dart';
import 'package:clide/builtin/vim/vim.dart';
import 'package:clide/builtin/tickets/tickets.dart';
import 'package:clide/builtin/todos/todos.dart';
import 'package:clide/builtin/welcome/welcome.dart';
import 'dart:io' show Directory, File, Platform;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/daemon/editor_commands.dart';
import 'package:clide/src/daemon/files_commands.dart';
import 'package:clide/src/daemon/git_commands.dart';
import 'package:clide/src/daemon/image_commands.dart';
import 'package:clide/src/daemon/pane_commands.dart';
import 'package:clide/src/daemon/status_command.dart';
import 'package:clide/src/daemon/ui_command.dart';
import 'package:clide/src/daemon/panel_commands.dart';
import 'package:clide/src/daemon/panel_resizer_kernel.dart';
import 'package:clide/src/daemon/pql_commands.dart';
import 'package:clide/src/daemon/search_commands.dart';
import 'package:clide/src/editor/registry.dart' show EditorRegistry;
import 'package:clide/src/git/client.dart';
import 'package:clide/src/cli/argv_dispatch.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/mcp_server.dart';
import 'package:clide/src/ipc/paths.dart' show workspaceSocketPath;
import 'package:clide/src/ipc/server.dart';
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
  // Gated on kDebugMode so the release tree-shaker can elide both the
  // branch and the test_app import graph — production binaries don't
  // ship the harness.
  if (kDebugMode) {
    const testMode = String.fromEnvironment('CLIDE_TESTMODE');
    if (testMode.isNotEmpty) {
      runApp(const ClideTestApp());
      return;
    }
  }

  binding.ensureSemantics();

  TreeSitterLib.init();

  final appDir = await _resolveAppDir();
  final themes = await _loadBundledThemes();

  // Resolve toolchain + boot daemon inline — same as Linux.
  // With proper signing (Developer ID), no sandbox or isolate needed.
  final toolchain = Toolchain();
  if (!kIsWeb) {
    toolchain.applyResolved(resolveToolchainPaths());
  }

  DaemonClient? ipcClient;
  DaemonBus? daemonBus;
  LayoutArrangement? kernelArrangement;
  PanelRegistry? kernelPanels;
  // Captured after boot so `clide status` can report the read-only reader's
  // viewed doc (D-81), which isn't an editor buffer (T-221).
  ReaderNavRegistry? kernelReaderNav;
  // The kernel MessageBus, captured post-boot so `ui.open` can drive the GUI
  // readers (publish a 'selection') from the CLI — the drive-half of D-6 (T-231).
  MessageBus? kernelMessages;
  // The filter-state cache, captured post-boot so `ui.filter` can read a
  // box's current value back — the observe-half of D-6 (T-270).
  FilterStateCache? kernelFilterStates;
  // IPC socket server (T-99 / T-124, per D-70/71/72). One server per
  // workspace; restarted when the active project switches because the
  // socket path is workspace-derived. The local DaemonClient connects
  // back to it over the socket so all IPC — including from UI widgets
  // in the same process — goes through the wire contract (T-127).
  IpcServer? ipcServer;
  // MCP server (T-130, per D-68 + D-73). Localhost HTTP+SSE, advertised
  // via $HOME/.claude/ide/<pid>.lock so Claude Code's /ide command
  // discovers it. Restarted alongside the unix server on project
  // switch so the discovery file reports the current workspace.
  McpServer? mcpServer;
  final ipcLog = Logger();

  // IPC-server swaps must run one-at-a-time — see the swapIpcServer wrapper
  // below doSwapIpcServer for why. (T-352)
  Future<void> swapChain = Future<void>.value();

  Future<void> doSwapIpcServer(DaemonDispatcher dispatcher, Directory workRoot) async {
    if (kIsWeb) return;
    // Already serving this exact workspace? Reuse the live server.
    // The startup factory binds the launch CWD, then the project-open
    // flow fires for (usually) that same path — tearing the server
    // down and rebinding would drop every live connection (the UI's
    // DaemonClient, the Claude pane's spawn gate fires right on
    // ProjectOpened) for no gain, leaving panes stranded. A genuine
    // project switch (different path) falls through and rebinds.
    final live = ipcServer;
    if (live != null && live.isRunning && live.workspaceRoot == workRoot.path) {
      ipcLog.info('ipc', 'already serving ${workRoot.path}; reusing the live server');
      // Idempotent — a no-op when the client is already connected here.
      await ipcClient?.reconnectAt(live.socketPath);
      return;
    }
    try {
      await ipcServer?.stop();
    } catch (e, st) {
      ipcLog.warn('ipc', 'stop failed during swap: $e');
      ipcLog.debug('ipc', '$st');
    }
    try {
      await mcpServer?.stop();
    } catch (e) {
      ipcLog.warn('mcp', 'stop failed during swap: $e');
    }
    final server = IpcServer(
      dispatcher: dispatcher,
      workspaceRoot: workRoot.path,
      log: ipcLog,
      events: daemonBus,
    );
    ipcServer = server;
    try {
      await server.start();
    } catch (e, st) {
      ipcLog.error('ipc', 'server start failed', error: e, stackTrace: st);
      return;
    }
    final mcp = McpServer(workspaceRoot: workRoot.path, log: ipcLog, dispatcher: dispatcher);
    mcpServer = mcp;
    try {
      await mcp.start();
    } catch (e, st) {
      ipcLog.warn('mcp', 'MCP server start failed (non-fatal): $e');
      ipcLog.debug('mcp', '$st');
    }
    // Point the in-process DaemonClient at the new socket. On first
    // boot (no client yet) the daemonClientFactory below kicks it
    // off; on project switch we just reconnect to the new path.
    final client = ipcClient;
    if (client != null) {
      await client.reconnectAt(server.socketPath);
    }
  }

  // Serialize IPC-server swaps. The boot factory fires a swap to the launch
  // CWD with unawaited(); the project-open flow then fires another to the
  // real repo. Unserialized, the two interleave and the late-finishing boot
  // swap can clobber the repo bind — reconnecting the daemon client to the
  // launch-CWD (HOME) socket, so pql/git/files run against the wrong
  // workspace. That surfaced as the ticket/decision sidebars failing on first
  // load (stale/global pql.db) yet working after a manual refresh. Chaining
  // every swap makes them apply in call order; the repo swap is issued last
  // and therefore wins. (T-352)
  Future<void> swapIpcServer(DaemonDispatcher dispatcher, Directory workRoot) {
    final next = swapChain.then((_) => doSwapIpcServer(dispatcher, workRoot));
    // A failed swap must not break the chain for the next one.
    swapChain = next.catchError((Object _) {});
    return next;
  }

  DaemonDispatcher buildDispatcher(
    DaemonBus events,
    Toolchain tc,
    Directory workRoot,
    LayoutArrangement arrangement,
    PanelRegistry panels,
  ) {
    final dispatcher = DaemonDispatcher();
    final eventSink = _BusEventSink(events);
    final paneRegistry = PaneRegistry(events: eventSink);
    // D-6 parity (T-219, D-83): make the tabs the user sees in the GUI
    // visible to `pane list` by snapshotting the kernel PanelRegistry +
    // LayoutArrangement at request time — no mirrored state to drift.
    registerPaneCommands(
      dispatcher,
      paneRegistry,
      viewPanes: () => snapshotViewPanes(panels, arrangement),
    );
    // Trusted read-only roots beyond the workspace: the global Claude
    // config dir (~/.claude), so the reader can open user-scope skill /
    // agent / command markdown the Config tab surfaces (D-80, T-195).
    // The repo-local .claude is already under workRoot.
    final extraReadRoots = <Directory>[];
    final claudeHome = Platform.environment['HOME'];
    if (claudeHome != null) {
      final globalClaude = Directory('$claudeHome/.claude');
      if (globalClaude.existsSync()) extraReadRoots.add(globalClaude);
    }
    final filesService = FilesService(root: workRoot, events: eventSink, extraReadRoots: extraReadRoots);
    registerFilesCommands(dispatcher, filesService);
    // Search reuses the files service's resolved ignore set so the
    // grep honours the same ignore_files: layering (D-4 / D-79).
    final searchService = SearchService(
      root: workRoot,
      ignore: filesService.ignore,
      events: eventSink,
    );
    registerSearchCommands(dispatcher, searchService);
    final editorRegistry = EditorRegistry(events: eventSink, workspaceRoot: workRoot);
    registerEditorCommands(dispatcher, editorRegistry);
    final gitClient = GitClient(toolchain: tc, workDir: workRoot);
    registerGitCommands(dispatcher, gitClient, eventSink);
    final pql = PqlClient(workDir: workRoot, toolchain: tc);
    registerPqlCommands(dispatcher, pql);
    registerPanelCommands(dispatcher, ArrangementPanelResizer(arrangement));
    // `clide ui open <reader> <id|path>` — drive the GUI readers from the CLI
    // (T-231, drive-half of D-6). Publishes a 'selection' to the kernel
    // MessageBus, captured post-boot; null in headless contexts.
    registerUiCommands(
      dispatcher,
      () => kernelMessages?.publish,
      filterValue: (address) => kernelFilterStates?.get(address),
    );
    // `clide image show <path>` — drive an image card into the Claude
    // conversation log (T-249, drive-half of D-6). Resolves the path
    // (workspace-relative → absolute, must exist) here where workRoot is in
    // scope, then publishes an 'image' message the Claude extension injects.
    registerImageCommands(
      dispatcher,
      () => kernelMessages?.publish,
      resolve: (path) {
        final file = File(path.startsWith('/') ? path : '${workRoot.path}/$path');
        return file.existsSync() ? file.absolute.path : null;
      },
    );
    // `clide status` — one-shot orientation snapshot (T-221): active pane,
    // focused file + selection, git summary, layout. Assembled here where the
    // live kernel + subsystem state is in scope; the reader's viewed doc is
    // read from the post-boot-captured ReaderNavRegistry (D-81).
    registerStatusCommand(dispatcher, () async {
      Map<String, Object?>? gitJson;
      try {
        final git = await gitClient.status();
        gitJson = {
          'branch': git.branch,
          if (git.upstream != null) 'upstream': git.upstream,
          'ahead': git.ahead,
          'behind': git.behind,
          'clean': git.isClean,
          'hasConflicts': git.hasConflicts,
          'counts': {
            'staged': git.staged.length,
            'unstaged': git.unstaged.length,
            'untracked': git.untracked.length,
            'conflicted': git.conflicted.length,
          },
        };
      } catch (_) {
        gitJson = null; // never sink the snapshot on a git hiccup
      }
      final editorActive = editorRegistry.active;
      return {
        'workspace': workRoot.path,
        'git': gitJson,
        'editor': editorActive == null
            ? null
            : {
                'id': editorActive.id,
                'path': editorActive.path,
                'selection': editorActive.selection.toJson(),
                'dirty': editorActive.dirty,
              },
        'readers': kernelReaderNav?.currentByReader ?? const <String, String>{},
        'focusedFile': editorActive?.path,
        'panes': [for (final v in snapshotViewPanes(panels, arrangement)) v.toJson()],
        'layout': {
          'focusMode': arrangement.focusModeSlot?.value,
          'slots': [
            for (final id in arrangement.slotsInOrder)
              {
                'id': id.value,
                'position': arrangement.positionOf(id)?.name,
                'visible': arrangement.isVisible(id),
                'collapsed': arrangement.isCollapsed(id),
                if (arrangement.sizeOf(id) != null) 'size': arrangement.sizeOf(id),
              },
          ],
        },
      };
    });
    registerArgvUnwrap(dispatcher);
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
        : (log, events, arrangement, panels) {
            daemonBus = events;
            kernelArrangement = arrangement;
            kernelPanels = panels;
            final workRoot = FilesService.atCwd(events: _BusEventSink(events)).root;
            final dispatcher = buildDispatcher(events, toolchain, workRoot, arrangement, panels);
            // Build the client at the workspace's socket path. The
            // server is started below (swapIpcServer) which the
            // client will then auto-connect to via its reconnect
            // loop. autoStartDaemonClient:false means we own the
            // lifecycle here.
            final client = DaemonClient(
              socketPath: workspaceSocketPath(workRoot.path),
              log: log,
              events: events,
            );
            ipcClient = client;
            // start() synchronously marks the client "connecting" (so
            // requests issued during the startup window park for the
            // socket instead of failing) and arms the reconnect loop.
            // swapIpcServer then binds the server and reconnectAt makes
            // the connect immediate. _connect's already-connected guard
            // keeps these two paths from opening a second socket.
            unawaited(client.start());
            unawaited(swapIpcServer(dispatcher, workRoot));
            return client;
          },
    onProjectOpen: kIsWeb
        ? null
        : (path) async {
            final bus = daemonBus;
            final arrangement = kernelArrangement;
            final panels = kernelPanels;
            if (bus == null || arrangement == null || panels == null) return;
            final dispatcher = buildDispatcher(bus, toolchain, Directory(path), arrangement, panels);
            await swapIpcServer(dispatcher, Directory(path));
          },
  );
  // Expose the reader nav to the `clide status` snapshot (T-221). Boot
  // creates it before the daemonClientFactory runs, but the status closure
  // only reads it at request time (post-boot), so capturing it here is safe.
  kernelReaderNav = services.readerNav;
  kernelMessages = services.messages;
  kernelFilterStates = services.filterStates;
  // Tee the IPC/MCP logger into the shared ring so the output dock (T-54)
  // shows socket-side logs alongside kernel/extension ones.
  ipcLog.addSink(services.logRing.add);

  // Register every built-in. Tier 0 activates only the four that do
  // real work; the rest compile in as stubs so the extensions-ui can
  // list them when Tier 6 lands.
  // Registration order = default icon rail order (left to right).
  // User can override via project.layout.sidebar.order in settings.
  services.extensions
    ..register(DefaultLayoutExtension())
    ..register(WelcomeExtension())
    ..register(OutputExtension())
    ..register(ThemePickerExtension())
    // Sidebar: tickets first, then decisions, files, git, pql, problems
    ..register(TicketsExtension())
    ..register(DecisionsExtension())
    ..register(FilesExtension())
    ..register(SearchExtension())
    ..register(GitExtension())
    ..register(PqlExtension())
    ..register(ProblemsExtension())
    ..register(DeepLinkExtension())
    // Workspace
    ..register(ClaudeExtension())
    ..register(TerminalExtension())
    ..register(EditorExtension())
    ..register(VimExtension())
    ..register(DiffExtension())
    // Format engines + stubs
    ..register(GrammarsCoreExtension())
    ..register(MarkdownExtension())
    ..register(TodosExtension())
    ..register(CanvasExtension())
    ..register(GraphExtension())
    // UI extensions
    ..register(ViewExtension(textZoom: services.textZoom))
    ..register(MenuBarExtension(services: services))
    ..register(SettingsUiExtension())
    ..register(ExtensionsUiExtension())
    ..register(KeybindingsUiExtension())
    ..register(ClaudeControlExtension())
    ..register(CliInstallExtension());

  await services.extensions.activateAll();

  if (!kIsWeb) {
    await services.project.loadRecents();
    // T-115: picker-first. Auto-open only when exactly one recent has
    // its sticky-startup flag set; otherwise the welcome tab (default
    // workspace content) serves as the project picker.
    final opened = await services.project.openStickyOrNothing();
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
    'lib/kernel/src/theme/themes/clide-hc.yaml',
    'lib/kernel/src/theme/themes/midnight-hc.yaml',
    'lib/kernel/src/theme/themes/paper-hc.yaml',
    'lib/kernel/src/theme/themes/terminal-hc.yaml',
    'lib/kernel/src/theme/themes/catppuccin-mocha.yaml',
    'lib/kernel/src/theme/themes/catppuccin-mocha-hc.yaml',
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
