import 'dart:async';

import 'package:clide/builtin/editor/src/editor_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

/// Tier-2 editor pane. Contributes a single workspace tab that
/// renders the daemon's active buffer. Multi-file tabs live in the
/// follow-up plan; today the pane is one-at-a-time.
class EditorExtension extends ClideExtension {
  @override
  String get id => 'builtin.editor';
  @override
  String get title => 'Editor';
  @override
  String get version => '0.1.0';
  @override
  List<String> get dependsOn => const [];

  StreamSubscription<DaemonEvent>? _sub;

  /// Reveal the editor split when a buffer opens, hide it when the last
  /// one closes. `editor.open` opens the buffer daemon-side and emits the
  /// event, but the workspace renders its editor split off
  /// `arrangement.editorOpen` (not the active tab) — so without flipping
  /// that flag the editor never appears over the Claude pane (T-197). The
  /// view's `hydrate()` pulls the active buffer once it mounts.
  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _sub = ctx.events.on<DaemonEvent>().listen((e) {
      if (e.subsystem != 'editor') return;
      switch (e.kind) {
        case 'editor.opened':
          ctx.arrangement.openEditor();
          ctx.panels.activateTab(Slots.workspace, 'editor.active');
        case 'editor.active-changed':
          // A null id means the last buffer closed — collapse the split.
          if (e.data['id'] == null) {
            ctx.arrangement.closeEditor();
          } else {
            ctx.arrangement.openEditor();
            ctx.panels.activateTab(Slots.workspace, 'editor.active');
          }
      }
    });
  }

  @override
  Future<void> deactivate() async => _sub?.cancel();

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'editor.active',
          slot: Slots.workspace,
          title: 'Editor',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: 80, // between Claude (90) and welcome (-100)
          build: (_) => const EditorView(),
        ),
      ];
}
