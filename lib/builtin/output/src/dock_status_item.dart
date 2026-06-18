/// Status-bar widget for the output dock (T-54 / D-87): merged health +
/// toggle. Replaces the old app-status item — green ✓ when the log is clean,
/// ⚠/✕ counts when not; click (or ⌘J) toggles the dock; chevron shows state.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class DockStatusItem extends StatefulWidget {
  const DockStatusItem({super.key});

  @override
  State<DockStatusItem> createState() => _DockStatusItemState();
}

class _DockStatusItemState extends State<DockStatusItem> {
  KernelServices? _kernel;
  StreamSubscription<void>? _ringSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final k = ClideKernel.of(context);
    if (identical(k, _kernel)) return;
    _kernel = k;
    _ringSub?.cancel();
    _ringSub = k.logRing.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _toggle(KernelServices kernel) {
    final a = kernel.arrangement;
    final opening = !a.isVisible(Slots.dock);
    a.setVisible(Slots.dock, opening);
    if (opening && kernel.panels.activeTabIn(Slots.dock) == null) {
      kernel.panels.activateTab(Slots.dock, 'output.panel');
    }
  }

  @override
  void dispose() {
    _ringSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    return ListenableBuilder(
      listenable: kernel.arrangement,
      builder: (ctx, _) {
        final tokens = ClideSettings.theme.of(ctx).surface;
        final open = kernel.arrangement.isVisible(Slots.dock);
        final errors = kernel.logRing.countAtLeast(LogLevel.error);
        final warns = kernel.logRing.countAtLeast(LogLevel.warn) - errors;
        final (String badge, Color color) = errors > 0
            ? ('✕ $errors', tokens.statusError)
            : warns > 0
            ? ('⚠ $warns', tokens.statusWarning)
            : ('✓', tokens.statusSuccess);
        final dockLabel = ClideSettings.i18n.string(ctx, 'dock.label', namespace: 'builtin.output', placeholder: 'Output');
        return Semantics(
          button: true,
          label: ClideSettings.i18n.string(ctx, 'a11y.toggleDock', namespace: 'builtin.output', placeholder: 'toggle output dock'),
          child: GestureDetector(
            onTap: () => _toggle(kernel),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClideText('${open ? '▼' : '▲'} $dockLabel ', fontSize: clideFontCaption, color: tokens.globalForeground),
                    ClideText(badge, fontSize: clideFontCaption, color: color),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
