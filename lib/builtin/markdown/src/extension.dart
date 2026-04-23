import 'dart:async';

import 'package:clide/builtin/markdown/src/markdown_viewer.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

class MarkdownExtension extends ClideExtension {
  @override
  String get id => 'builtin.markdown';
  @override
  String get title => 'Markdown';
  @override
  String get version => '0.2.0';
  @override
  List<String> get dependsOn => const ['builtin.editor'];

  ClideExtensionContext? _ctx;
  StreamSubscription<DaemonEvent>? _editorSub;
  bool _viewerSpawned = false;

  @override
  List<ContributionPoint> get contributions => const [];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    _editorSub = ctx.events.on<DaemonEvent>().listen((e) {
      if (e.subsystem != 'editor') return;
      if (e.kind == 'editor.active-changed' || e.kind == 'editor.opened') {
        final path = e.data['path'] as String?;
        if (path != null && path.endsWith('.md')) {
          _spawnViewer();
        }
      }
    });
  }

  @override
  Future<void> deactivate() async {
    _editorSub?.cancel();
    if (_viewerSpawned) {
      _ctx?.panels.uncontribute('markdown.viewer');
      _viewerSpawned = false;
    }
  }

  void _spawnViewer() {
    final ctx = _ctx;
    if (ctx == null || _viewerSpawned) return;
    ctx.panels.contribute(TabContribution(
      id: 'markdown.viewer',
      slot: Slots.contextPanel,
      title: 'Viewer',
      priority: -100,
      build: (_) => const MarkdownViewer(),
    ));
    _viewerSpawned = true;
    ctx.panels.activateTab(Slots.contextPanel, 'markdown.viewer');
  }
}
