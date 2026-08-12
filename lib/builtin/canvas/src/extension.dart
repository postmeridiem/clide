import 'dart:async';

import 'package:clide/builtin/canvas/src/canvas_pane_host.dart';
import 'package:clide/builtin/canvas/src/canvas_store.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/canvas_commands.dart' show CanvasDocuments;
import 'package:clide/widgets/widgets.dart';

/// Tier-5 interactive `.canvas` pane (T-322). Renders Obsidian JSONCanvas
/// documents in a workspace tab; each open document is a real sub-tab
/// (MultitabPane). Opens route in as `selection` messages — from
/// `openWorkspaceFile` (file tree, quick-open) and from
/// `clide ui open canvas [path]` (D-6 parity, the diff/T-233 pattern).
class CanvasExtension extends ClideExtension {
  @override
  String get id => 'builtin.canvas';
  @override
  String get title => 'Canvas';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  /// App-scoped so open documents survive the pane view being (re)built
  /// while another workspace tab is active. Built in [activate]; the
  /// contribution's build closure reads the field at widget-build time.
  MultitabController<String>? _tabs;

  /// The working documents. Lives here rather than in the tab widget so the
  /// `canvas.*` verbs can drive the same state the pane renders (T-570).
  CanvasDocumentStore? _store;

  StreamSubscription<Message>? _selectionSub;
  StreamSubscription<ProjectOpened>? _projectSub;
  String? _projectRoot;

  /// The open documents, for the `canvas.*` command handlers. Null before
  /// activation — the verbs report "no live UI" then.
  CanvasDocuments? get documents => _store;

  @override
  List<ContributionPoint> get contributions => [
    TabContribution(
      id: 'canvas.view',
      slot: Slots.workspace,
      title: 'Canvas',
      titleKey: 'tab.title',
      i18nNamespace: id,
      priority: -60, // below the readers' home surfaces, near diff (-70)
      build: (_) => CanvasPaneHost(tabs: _tabs, store: _store),
    ),
  ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _tabs = MultitabController<String>();
    _store = CanvasDocumentStore(ipc: ctx.ipc, messages: ctx.messages, i18n: ctx.i18n);
    _selectionSub = ctx.messages.subscribe(publisher: id, channel: 'selection').listen((msg) {
      final path = msg.data['path'];
      if (path is! String || path.isEmpty) return;
      openPath(path);
      ctx.panels.activateTab(Slots.workspace, 'canvas.view');
    });
    _projectSub = ctx.events.on<ProjectOpened>().listen(_onProjectChanged);
  }

  /// Focus the sub-tab for [path], opening one when the document isn't
  /// open yet. Tab id is the path itself — one tab per document.
  void openPath(String path) {
    final tabs = _tabs;
    if (tabs == null) return;
    if (tabs.entries.any((e) => e.id == path)) {
      tabs.activate(path);
    } else {
      tabs.add(MultitabEntry<String>(id: path, title: _basename(path), payload: path));
    }
  }

  /// Paths of the open documents, oldest-first.
  List<String> get openPaths => _tabs?.entries.map((e) => e.id).toList() ?? const [];

  /// Drop every open document when the workspace switches in place
  /// (T-269): the old repo's paths don't resolve in the new one.
  void _onProjectChanged(ProjectOpened e) {
    final prev = _projectRoot;
    _projectRoot = e.path;
    if (prev == null || prev == e.path) return;
    _store?.closeAll();
    final tabs = _tabs;
    if (tabs == null) return;
    for (final id in tabs.entries.map((x) => x.id).toList()) {
      tabs.remove(id);
    }
  }

  static String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }

  @override
  Future<void> deactivate() async {
    await _selectionSub?.cancel();
    _selectionSub = null;
    await _projectSub?.cancel();
    _projectSub = null;
    _tabs?.dispose();
    _tabs = null;
    _store?.dispose();
    _store = null;
  }
}
