import 'dart:async';

import 'package:clide/builtin/pql/src/backlinks_view.dart';
import 'package:clide/builtin/pql/src/pql_panel_view.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

class PqlExtension extends ClideExtension {
  @override
  String get id => 'builtin.pql';
  @override
  String get title => 'pql';
  @override
  String get version => '0.2.0';
  @override
  List<String> get dependsOn => const [];

  ClideExtensionContext? _ctx;
  StreamSubscription<DaemonEvent>? _editorSub;
  bool _backlinksSpawned = false;

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'pql.panel',
          slot: Slots.sidebar,
          title: 'pql',
          titleKey: 'tab.title',
          i18nNamespace: id,
          priority: -60,
          build: (_) => const PqlPanelView(),
        ),
      ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    _editorSub = ctx.events.on<DaemonEvent>().listen((e) {
      if (e.subsystem != 'editor') return;
      if (e.kind == 'editor.active-changed' || e.kind == 'editor.opened') {
        _spawnBacklinks();
      }
    });
  }

  @override
  Future<void> deactivate() async {
    _editorSub?.cancel();
    _despawnBacklinks();
  }

  void _spawnBacklinks() {
    final ctx = _ctx;
    if (ctx == null || _backlinksSpawned) return;
    ctx.panels.contribute(TabContribution(
      id: 'pql.backlinks',
      slot: Slots.contextPanel,
      title: 'Links',
      priority: -80,
      build: (_) => const BacklinksView(),
    ));
    _backlinksSpawned = true;
    ctx.panels.activateTab(Slots.contextPanel, 'pql.backlinks');
  }

  void _despawnBacklinks() {
    if (_backlinksSpawned) {
      _ctx?.panels.uncontribute('pql.backlinks');
      _backlinksSpawned = false;
    }
  }
}
