import 'dart:async';

import 'package:clide/builtin/diff/src/diff_controller.dart';
import 'package:clide/builtin/diff/src/diff_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

class DiffExtension extends ClideExtension {
  @override
  String get id => 'builtin.diff';
  @override
  String get title => 'Diff';
  @override
  String get version => '0.2.0';
  @override
  List<String> get dependsOn => const [];

  /// App-scoped controller retained across tab reveal/remount so a
  /// `ui open diff <path>` focus survives the view being (re)built (T-233).
  /// Built in [activate] where the kernel ipc/events are in scope; the view
  /// renders it but does not own it.
  DiffController? _controller;
  StreamSubscription<Message>? _sub;

  @override
  List<ContributionPoint> get contributions => [
    TabContribution(
      id: 'diff.view',
      slot: Slots.workspace,
      title: 'Diff',
      titleKey: 'tab.title',
      i18nNamespace: id,
      priority: -70,
      build: (_) => DiffView(controller: _controller),
    ),
  ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _controller = DiffController(ipc: ctx.ipc, events: ctx.events)..load();
    // `clide ui open diff <path>` publishes a 'selection' here (T-233, the
    // diff-panel arm of D-6 parity). Reveal the diff tab and focus the file —
    // the same reveal mechanism the ReaderNav viewers use for their tabs.
    _sub = ctx.messages.subscribe(publisher: id, channel: 'selection').listen((msg) {
      final path = msg.data['path'];
      if (path is! String || path.isEmpty) return;
      ctx.panels.activateTab(Slots.workspace, 'diff.view');
      _controller?.focus(path);
    });
  }

  @override
  Future<void> deactivate() async {
    await _sub?.cancel();
    _sub = null;
    _controller?.dispose();
    _controller = null;
  }
}
