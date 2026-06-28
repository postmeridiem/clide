import 'dart:async';

import 'package:clide/builtin/markdown/src/markdown_viewer.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';

class MarkdownExtension extends ClideExtension {
  @override
  String get id => 'builtin.markdown';
  @override
  String get title => 'Markdown';
  @override
  String get version => '0.3.0';
  @override
  List<String> get dependsOn => const [];

  StreamSubscription<Message>? _sub;
  StreamSubscription<DaemonEvent>? _editorSub;

  @override
  List<ContributionPoint> get contributions => [
    TabContribution(
      id: 'markdown.viewer',
      slot: Slots.contextPanel,
      title: 'Markdown',
      icon: PhosphorIcons.byName('file-text'),
      build: (_) => const MarkdownViewer(),
    ),
  ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    // Ensure the retained nav exists so it records selections + emits
    // loads whether or not the viewer is mounted (T-196). This handler
    // only reveals the tab; the nav owns load + history.
    ctx.readerNav.navFor(id, dataKey: 'path');
    _sub = ctx.messages.subscribe(publisher: id, channel: 'selection').listen((msg) {
      if (msg.data['path'] is! String) return;
      ctx.panels.activateTab(Slots.contextPanel, 'markdown.viewer');
    });
    // Live-sync read-mirror (T-36, D-50 behavior 4): opening a renderable .md in
    // the editor auto-reveals the reader, which then mirrors the buffer live.
    // Non-renderable files reveal nothing (D-50 behavior 5).
    _editorSub = ctx.events.on<DaemonEvent>().listen((e) {
      if (e.subsystem != 'editor' || e.kind != 'editor.opened') return;
      final path = e.data['path'] as String?;
      if (path != null && isRenderableMarkdownPath(path)) {
        ctx.panels.activateTab(Slots.contextPanel, 'markdown.viewer');
      }
    });
  }

  @override
  Future<void> deactivate() async {
    await _sub?.cancel();
    await _editorSub?.cancel();
  }
}
