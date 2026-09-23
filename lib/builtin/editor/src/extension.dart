import 'dart:async';
import 'dart:io';

import 'package:clide/builtin/editor/src/editor_view.dart';
import 'package:clide/builtin/editor/src/open_files_store.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

/// Tier-2 editor pane. Contributes a single workspace tab that
/// renders the daemon's active buffer. Multi-file tabs live in the
/// follow-up plan; today the pane is one-at-a-time.
///
/// The open files are remembered per workspace and reopened when it opens
/// again — after a restart, a crash or an update (D-114).
class EditorExtension extends ClideExtension {
  @override
  String get id => 'builtin.editor';
  @override
  String get title => 'Editor';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  final List<StreamSubscription<dynamic>> _subs = [];
  ClideExtensionContext? _ctx;
  OpenFilesStore? _store;

  /// The workspace whose files are being tracked, and what's open in it.
  String? _root;
  List<String> _paths = [];
  String? _active;
  OpenFiles _saved = const OpenFiles();

  /// Reopening the remembered files: their `editor.opened` events mustn't
  /// pull the editor to the front, and nothing is saved until it's done.
  bool _restoring = false;

  /// Reveal the editor split when a buffer opens, hide it when the last
  /// one closes. `editor.open` opens the buffer daemon-side and emits the
  /// event, but the workspace renders its editor split off
  /// `arrangement.editorOpen` (not the active tab) — so without flipping
  /// that flag the editor never appears over the Claude pane (T-197). The
  /// view's `hydrate()` pulls the active buffer once it mounts.
  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    _store = OpenFilesStore(ctx.settings);
    _subs.add(ctx.events.on<DaemonEvent>().listen((e) => _onEditorEvent(ctx, e)));
    _subs.add(ctx.events.on<ProjectOpened>().listen((e) => unawaited(_onProject(e.path))));
    ctx.arrangement.addListener(_remember);
    final current = ctx.project.current?.path;
    if (current != null) unawaited(_onProject(current));
  }

  void _onEditorEvent(ClideExtensionContext ctx, DaemonEvent e) {
    if (e.subsystem != 'editor') return;
    final path = e.data['path'] as String?;
    switch (e.kind) {
      case 'editor.opened':
        if (path != null && !_paths.contains(path)) _paths.add(path);
        if (!_restoring) {
          ctx.arrangement.openEditor();
          ctx.panels.activateTab(Slots.workspace, 'editor.active');
        }
      case 'editor.closed':
        _paths.remove(path);
      case 'editor.active-changed':
        _active = path;
        // A null id means the last buffer closed — collapse the split.
        if (e.data['id'] == null) {
          ctx.arrangement.closeEditor();
        } else if (!_restoring) {
          ctx.arrangement.openEditor();
          ctx.panels.activateTab(Slots.workspace, 'editor.active');
        }
      default:
        return;
    }
    _remember();
  }

  /// A workspace opened: its buffers start empty (a fresh registry), so
  /// reopen the files it had.
  Future<void> _onProject(String root) async {
    if (_root == root) return;
    _root = root;
    _paths = [];
    _active = null;
    final ctx = _ctx;
    final store = _store;
    if (ctx == null || store == null) return;
    final remembered = store.load(root);
    _saved = remembered;
    final files = [
      for (final p in remembered.paths)
        if (_exists(root, p)) p,
    ];
    if (files.isEmpty) return;
    _restoring = true;
    String? activeId;
    try {
      for (final p in files) {
        final r = await ctx.ipc.request('editor.open', args: {'path': p});
        if (r.ok && p == remembered.active) activeId = r.data['id'] as String?;
      }
      if (activeId != null) await ctx.ipc.request('editor.activate', args: {'id': activeId});
      // Let the events of those opens land while they still count as a restore.
      await Future<void>.delayed(Duration.zero);
    } finally {
      _restoring = false;
    }
    if (_root != root) return; // switched away meanwhile
    if (remembered.visible) ctx.arrangement.openEditor();
    _remember();
  }

  static bool _exists(String root, String path) => File(path.startsWith('/') ? path : '$root/$path').existsSync();

  void _remember() {
    final root = _root;
    final store = _store;
    final ctx = _ctx;
    if (_restoring || root == null || store == null || ctx == null) return;
    final now = OpenFiles(paths: List.of(_paths), active: _active, visible: ctx.arrangement.editorOpen && _paths.isNotEmpty);
    if (now.sameAs(_saved)) return;
    _saved = now;
    unawaited(store.save(root, now));
  }

  @override
  Future<void> deactivate() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _ctx?.arrangement.removeListener(_remember);
  }

  @override
  List<ContributionPoint> get contributions => [
    TabContribution(
      id: 'editor.active',
      slot: Slots.workspace,
      title: 'Editor',
      titleKey: 'tab.title',
      i18nNamespace: id,
      priority: 80, // between Claude (90) and welcome (-100)
      subjectSource: id, // the active buffer's path, supplied by the host
      build: (_) => const EditorView(),
    ),
  ];
}
