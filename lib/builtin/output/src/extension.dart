/// The output-dock builtin (T-54 / D-87): contributes the Output tab + the
/// merged health/toggle status-bar widget, and the `dock.toggle` command.
library;

import 'dart:async';

import 'package:clide/builtin/output/src/dock_status_item.dart';
import 'package:clide/builtin/output/src/output_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

class OutputExtension extends ClideExtension {
  ClideExtensionContext? _ctx;

  @override
  String get id => 'builtin.output';
  @override
  String get title => 'Output';
  @override
  String get version => '0.1.0';

  /// The dock slot is registered by the default-layout preset; depend on it so
  /// the slot exists before this tab contributes.
  @override
  List<String> get dependsOn => const ['builtin.default-layout'];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
  }

  @override
  List<ContributionPoint> get contributions => [
    TabContribution(
      id: 'output.panel',
      slot: Slots.dock,
      title: 'Output',
      priority: -100, // sort before Problems in the dock tab bar
      build: (ctx) {
        // The Level chip is the live verbosity toggle (T-433): drive the kernel
        // logger + persist app.log.level so the choice survives restart and
        // matches the `clide log level` CLI (D-6 parity).
        final k = ClideKernel.of(ctx);
        return OutputView(
          ring: k.logRing,
          initialLevel: k.log.minLevel,
          onMinLevelChanged: (level) {
            k.log.minLevel = level;
            unawaited(k.settings.set('app.log.level', level.name));
          },
        );
      },
    ),
    StatusItemContribution(
      id: 'output.dock-toggle',
      priority: 100, // right group, replacing the old app-status item
      build: (_) => const DockStatusItem(),
    ),
    CommandContribution(
      id: 'dock.toggle',
      command: 'dock.toggle',
      title: 'Toggle output dock',
      titleKey: 'command.dock.toggle',
      i18nNamespace: id,
      defaultBinding: 'ctrl+j',
      run: (_) async {
        final ctx = _ctx;
        if (ctx == null) return IpcResponse.ok(id: '', data: const {});
        final a = ctx.arrangement;
        final opening = !a.isVisible(Slots.dock);
        a.setVisible(Slots.dock, opening);
        if (opening && ctx.panels.activeTabIn(Slots.dock) == null) {
          ctx.panels.activateTab(Slots.dock, 'output.panel');
        }
        return IpcResponse.ok(id: '', data: {'dock': opening});
      },
    ),
  ];
}
