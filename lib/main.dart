import 'dart:async';
import 'dart:isolate';

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
import 'dart:io' show Directory, File, Platform, pid;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/builtin/claude/src/account_registry.dart';
import 'package:clide/clide.dart' show clideVersion;
import 'package:clide/src/daemon/claude_account_commands.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/daemon/editor_commands.dart';
import 'package:clide/src/daemon/files_commands.dart';
import 'package:clide/src/daemon/git_commands.dart';
import 'package:clide/src/daemon/image_commands.dart';
import 'package:clide/src/daemon/project_commands.dart';
import 'package:clide/src/daemon/instance_command.dart';
import 'package:clide/src/daemon/log_commands.dart';
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
import 'package:clide/src/env/shell_env.dart' show primeLoginShellPath;
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/mcp_server.dart';
import 'package:clide/src/ipc/paths.dart' show workspaceSocketPath, logDirectory;
import 'package:clide/src/pty/pty_log.dart';
import 'package:clide/src/ipc/server.dart';
import 'package:clide/src/panes/event_sink.dart';
import 'package:clide/src/panes/registry.dart';
import 'package:clide/src/pql/client.dart';
// Web fence (T-438, D-100): tree-sitter init is FFI-backed on desktop, a no-op
// on web (highlighting degrades to plain text there).
import 'package:clide/kernel/src/syntax/tree_sitter_boot_stub.dart' if (dart.library.ffi) 'package:clide/kernel/src/syntax/tree_sitter_boot_io.dart';
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

  initTreeSitter();

  final appDir = await _resolveAppDir();
  final themes = await _loadBundledThemes();

  // Resolve the workspace to boot the daemon at. A desktop launch starts in
  // HOME (not a git repo), so atCwd would point pql/git/files at HOME — where
  // pql hits a stale ~/.pql/pql.db and the sidebars error on first load. Boot
  // at the last project instead so the daemon targets the real repo from the
  // first request. (T-352)
  Directory startupWorkRoot = resolveWorkspaceRoot(Directory.current);
  // Crash-survivable logging (T-425): resolve the dev/prod verbosity once and
  // attach a FileLogSink as the leading sink so a freeze leaves on-disk
  // breadcrumbs. Desktop-only — the sink uses dart:io.
  LogLevel bootLogLevel = kReleaseMode ? LogLevel.warn : LogLevel.info;
  List<LogSink> bootLogSinks = const [];
  if (!kIsWeb) {
    // Resolve the user's real login-shell PATH once, before any tool resolution
    // or spawn — a desktop/dock launch inherits a sparse PATH that misses
    // ~/.local/bin, brew, nvm, etc. (T-439). Bounded + graceful: a slow/failed
    // probe just falls back to the process PATH + well-known dirs.
    await primeLoginShellPath();
    final bootSettings = SettingsStore(appDir: appDir);
    await bootSettings.load();
    startupWorkRoot = resolveStartupWorkspace(
      cwdRoot: startupWorkRoot,
      lastProject: bootSettings.get<String>('app.lastProject'),
      isGitRepo: (d) => Directory('${d.path}/.git').existsSync(),
    );
    bootLogLevel = resolveLogLevel(
      isRelease: kReleaseMode,
      dartDefine: const String.fromEnvironment('CLIDE_LOG'),
      envVar: Platform.environment['CLIDE_LOG'],
      settingValue: bootSettings.get<String>('app.log.level'),
    );
    bootLogSinks = [FileLogSink(dir: Directory(logDirectory())).call];
    // Crash-diagnostic watchdog in its own isolate (T-435): heartbeats +
    // resource samples that survive a frozen main isolate. Non-fatal — a
    // leak-detector that breaks startup is worse than a missing one. The OS
    // reaps the isolate on exit; every line is fsynced, so abrupt death loses
    // nothing.
    try {
      await Isolate.spawn(watchdogEntry, ('${logDirectory()}/clide-watchdog.log', 500, 2000));
    } catch (_) {}
  }

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
  // The kernel Logger, captured in the factory so a post-boot project switch
  // can rebuild the dispatcher with PTY breadcrumbs wired (T-434).
  Logger? kernelLog;
  // The kernel settings store, captured post-boot so `clide log level` can
  // persist app.log.level (T-433).
  SettingsStore? kernelSettings;
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

  // Backend swaps must run one-at-a-time — see the swapBackend wrapper
  // below doSwapBackend for why. (T-352)
  Future<void> swapChain = Future<void>.value();

  // Teardown of the service set behind the currently-served dispatcher
  // (pane PTYs, file watcher, in-flight searches, editor buffers). Swapped
  // alongside the IPC server so a project switch can't leak the previous
  // workspace's watchers into the new one's bus (T-367).
  Future<void> Function()? activeSubsystemTeardown;

  Future<void> doSwapBackend(DaemonDispatcher dispatcher, Future<void> Function() teardown, Directory workRoot) async {
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
      // The freshly built dispatcher is dropped unused — its services are
      // inert (watchers/PTYs only start via dispatched commands), so there
      // is nothing to tear down. The live server keeps its own set.
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
    // The old server is down — release the previous workspace's services
    // before the new set takes over (T-367). The shutdown() methods are
    // idempotent, so a failed swap retried later is safe.
    try {
      await activeSubsystemTeardown?.call();
    } catch (e, st) {
      ipcLog.warn('ipc', 'subsystem teardown failed during swap: $e');
      ipcLog.debug('ipc', '$st');
    }
    activeSubsystemTeardown = teardown;
    final server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot.path, log: ipcLog, events: daemonBus);
    ipcServer = server;
    try {
      await server.start();
    } catch (e, st) {
      ipcLog.error('ipc', 'server start failed', error: e, stackTrace: st);
      return;
    }
    final mcp = McpServer(
      workspaceRoot: workRoot.path,
      log: ipcLog,
      dispatcher: dispatcher,
      // T-479: when this workspace is bound to a Claude account, also write the
      // /ide discovery lock into that account's config dir so a `claude` started
      // with CLAUDE_CONFIG_DIR=<dir> can reach clide's bridge. Lazy — resolved
      // post-boot once kernelSettings (and the registry) exist.
      boundConfigDir: () {
        final s = kernelSettings;
        return s == null ? null : AccountRegistry(s).accountForWorkspace(workRoot.path)?.dir;
      },
    );
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
  Future<void> swapBackend(DaemonDispatcher dispatcher, Future<void> Function() teardown, Directory workRoot) {
    final next = swapChain.then((_) => doSwapBackend(dispatcher, teardown, workRoot));
    // A failed swap must not break the chain for the next one.
    swapChain = next.catchError((Object _) {});
    return next;
  }

  (DaemonDispatcher, Future<void> Function()) buildDispatcher(
    DaemonBus events,
    Toolchain tc,
    Directory workRoot,
    LayoutArrangement arrangement,
    PanelRegistry panels, {
    Logger? log,
  }) {
    final dispatcher = DaemonDispatcher();
    final eventSink = _BusEventSink(events);
    // FFI breadcrumbs (T-434): route PTY crumbs to the kernel Logger (source
    // 'conpty', an eager FileLogSink source) and a sendable crumb file the
    // reader/waiter isolates open themselves. Verbose (per-syscall) crumbs only
    // when the log level is debug/trace.
    final ptyLog = (log == null || kIsWeb)
        ? PtyLog.none
        : PtyLog(
            onCrumb: (m) => log.trace('conpty', m),
            crumbPath: '${logDirectory()}/clide-pty.crumbs.log',
            verbose: log.minLevel.index <= LogLevel.debug.index,
          );
    final paneRegistry = PaneRegistry(events: eventSink, ptyLog: ptyLog);
    // D-6 parity (T-219, D-83): make the tabs the user sees in the GUI
    // visible to `pane list` by snapshotting the kernel PanelRegistry +
    // LayoutArrangement at request time — no mirrored state to drift.
    registerPaneCommands(dispatcher, paneRegistry, viewPanes: () => snapshotViewPanes(panels, arrangement));
    // `clide instance` — this instance's identity (version/pid/workspace/socket)
    // so `clide instances` can list every live instance and a human/agent can
    // tell which one a socket belongs to (T-247).
    registerInstanceCommand(dispatcher, version: clideVersion, pid: pid, workspace: workRoot.path, socketPath: workspaceSocketPath(workRoot.path));
    // `clide log level [<level>]` — the live verbosity toggle's CLI half (T-433,
    // D-6 parity with the output-dock Level chip). Persists via the kernel
    // settings, captured post-boot.
    if (log != null) {
      registerLogCommands(dispatcher, log, (name) async => await kernelSettings?.set<String>('app.log.level', name));
    }
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
    final searchService = SearchService(root: workRoot, ignore: filesService.ignore, events: eventSink);
    registerSearchCommands(dispatcher, searchService);
    final editorRegistry = EditorRegistry(events: eventSink, workspaceRoot: workRoot);
    registerEditorCommands(dispatcher, editorRegistry);
    final gitClient = GitClient(toolchain: tc, workDir: workRoot);
    registerGitCommands(dispatcher, gitClient, eventSink);
    // `clide project new <name>` (T-487): create + git-init a new project dir.
    // git init runs over the *new* dir via the toolchain; --dir defaults to the
    // current workspace's parent so a new project lands beside this one.
    registerProjectCommands(
      dispatcher,
      gitInit: (dir) => GitClient(toolchain: tc, workDir: Directory(dir)).init(),
      defaultParent: () => workRoot.parent.path,
    );
    final pql = PqlClient(workDir: workRoot, toolchain: tc);
    registerPqlCommands(dispatcher, pql);
    registerPanelCommands(dispatcher, ArrangementPanelResizer(arrangement));
    // `clide ui open <reader> <id|path>` — drive the GUI readers from the CLI
    // (T-231, drive-half of D-6). Publishes a 'selection' to the kernel
    // MessageBus, captured post-boot; null in headless contexts.
    registerUiCommands(dispatcher, () => kernelMessages?.publish, filterValue: (address) => kernelFilterStates?.get(address));
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
    // `clide claude account …` — manage per-repo Claude accounts (T-480, epic
    // T-476). Registry reads/writes go through the user-scope SettingsStore;
    // side-effects (respawn, login pane, --purge) are published on
    // accountActionChannel for the Claude extension to perform.
    registerClaudeAccountCommands(
      dispatcher,
      () {
        final settings = kernelSettings;
        final home = Platform.environment['HOME'];
        if (settings == null || home == null || home.isEmpty) return null;
        return _AccountStoreAdapter(AccountRegistry(settings), home);
      },
      publisher: () => kernelMessages?.publish,
      workspaceCwd: () => workRoot.path,
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
          'counts': {'staged': git.staged.length, 'unstaged': git.unstaged.length, 'untracked': git.untracked.length, 'conflicted': git.conflicted.length},
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
            : {'id': editorActive.id, 'path': editorActive.path, 'selection': editorActive.selection.toJson(), 'dirty': editorActive.dirty},
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
    // Paired teardown for this workspace's stateful services — the swap
    // calls it when this dispatcher stops being served (T-367).
    Future<void> teardown() async {
      await paneRegistry.shutdown();
      await filesService.shutdown();
      await searchService.shutdown();
      await editorRegistry.shutdown();
    }

    return (dispatcher, teardown);
  }

  final services = await KernelServices.boot(
    appDir: appDir,
    bundledThemes: themes,
    i18nLoader: AssetCatalogLoader(bundle: rootBundle),
    preloadNamespaces: kTier0Namespaces,
    // Languages the UI can switch to (Settings → Appearance, T-462). Each needs
    // an assets/i18n/<locale>/ catalog folder; root_shell applies the persisted
    // app.locale on boot.
    availableLocales: const [Locale('en', 'US'), Locale('nl', 'NL')],
    autoStartDaemonClient: false,
    toolchain: toolchain,
    minLogLevel: bootLogLevel,
    additionalSinks: bootLogSinks,
    daemonClientFactory: kIsWeb
        ? null
        : (log, events, arrangement, panels) {
            daemonBus = events;
            kernelArrangement = arrangement;
            kernelPanels = panels;
            kernelLog = log;
            final workRoot = startupWorkRoot;
            final (dispatcher, teardown) = buildDispatcher(events, toolchain, workRoot, arrangement, panels, log: log);
            // Build the client at the workspace's socket path. The
            // server is started below (swapBackend) which the
            // client will then auto-connect to via its reconnect
            // loop. autoStartDaemonClient:false means we own the
            // lifecycle here.
            final client = DaemonClient.unixSocket(socketPath: workspaceSocketPath(workRoot.path), log: log, events: events);
            ipcClient = client;
            // start() synchronously marks the client "connecting" (so
            // requests issued during the startup window park for the
            // socket instead of failing) and arms the reconnect loop.
            // swapBackend then binds the server and reconnectAt makes
            // the connect immediate. _connect's already-connected guard
            // keeps these two paths from opening a second socket.
            unawaited(client.start());
            unawaited(swapBackend(dispatcher, teardown, workRoot));
            return client;
          },
    onProjectOpen: kIsWeb
        ? null
        : (path) async {
            final bus = daemonBus;
            final arrangement = kernelArrangement;
            final panels = kernelPanels;
            if (bus == null || arrangement == null || panels == null) return;
            final (dispatcher, teardown) = buildDispatcher(bus, toolchain, Directory(path), arrangement, panels, log: kernelLog);
            await swapBackend(dispatcher, teardown, Directory(path));
          },
  );
  // Expose the reader nav to the `clide status` snapshot (T-221). Boot
  // creates it before the daemonClientFactory runs, but the status closure
  // only reads it at request time (post-boot), so capturing it here is safe.
  kernelReaderNav = services.readerNav;
  kernelMessages = services.messages;
  kernelFilterStates = services.filterStates;
  kernelSettings = services.settings;
  // T-479: the account registry is now resolvable (kernelSettings is set), so
  // re-sync the /ide discovery locks to pick up any account bound to this
  // workspace at boot, and re-sync on every account binding change.
  unawaited(mcpServer?.syncDiscoveryLocks() ?? Future<void>.value());
  services.messages.subscribe(channel: accountActionChannel).listen((_) => unawaited(mcpServer?.syncDiscoveryLocks() ?? Future<void>.value()));
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

/// Adapts the foundation-bound [AccountRegistry] + bootstrap probe to the
/// Flutter-free [AccountStore] port the `claude account` verbs use (T-480).
class _AccountStoreAdapter implements AccountStore {
  _AccountStoreAdapter(this._reg, this._home);
  final AccountRegistry _reg;
  final String _home;

  @override
  List<({String name, String dir})> get accounts => [for (final a in _reg.accounts) (name: a.name, dir: a.dir)];
  @override
  String? boundAccountName(String cwd) => _reg.boundName(cwd);
  @override
  Set<String> boundAccountNames() => _reg.boundAccountNames();
  @override
  String defaultDirFor(String name) => '$_home/.claude-$name';
  @override
  List<String> detectedDirs() {
    final registered = {for (final a in _reg.accounts) a.dir};
    return [
      for (final d in probeExistingAccountDirs(_home))
        if (!registered.contains(d.dir)) d.dir,
    ];
  }

  @override
  Future<void> add(String name, String dir) => _reg.registerAccount(name, dir);
  @override
  Future<void> remove(String name) => _reg.removeAccount(name);
  @override
  Future<void> bind(String cwd, String name) => _reg.bindWorkspace(cwd, name);
  @override
  Future<void> unbind(String cwd) => _reg.unbindWorkspace(cwd);
}

class _BusEventSink implements DaemonEventSink {
  _BusEventSink(this._bus);
  final DaemonBus _bus;

  @override
  void emit(IpcEvent event) {
    _bus.emit(DaemonEvent(subsystem: event.subsystem, kind: event.kind, data: event.data, ts: DateTime.now()));
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
  final out = <ThemeDefinition>[];
  for (final p in kBundledThemePaths) {
    out.add(await loader.fromAsset(rootBundle, p));
  }
  return out;
}

// The Tier-0 i18n namespace list now lives in
// lib/kernel/src/i18n/tier0_namespaces.dart as `kTier0Namespaces`, the single
// source of truth shared with the i18n coverage gate (T-371).
