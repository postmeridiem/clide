/// Status-bar item that shows the *focused* pane's status widget
/// (T-150). The content comes from whichever pane is focused — each pane
/// surfaces its own [ClidePane.statusWidget] via [FocusTracker], so this
/// item is generic: it just renders `focus.activeStatusWidget`, clamped
/// to a fixed height and marquee-scrolled when it overflows. Nothing
/// (and no space) when no focused pane has a status — so it clears on
/// focus change.
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Max width the slot occupies in the status bar before marquee kicks in.
const double _slotMaxWidth = 360;

/// Fixed slot height — panes can render anything, but not blow up the bar.
const double _slotHeight = 16;

class PaneContextStatusItem extends StatelessWidget {
  const PaneContextStatusItem({super.key});

  @override
  Widget build(BuildContext context) {
    final focus = ClideKernel.of(context).focus;
    return ListenableBuilder(
      listenable: focus,
      builder: (ctx, _) {
        final widget = focus.activeStatusWidget;
        if (widget == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            height: _slotHeight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _slotMaxWidth),
              child: ClideMarquee(child: widget),
            ),
          ),
        );
      },
    );
  }
}
