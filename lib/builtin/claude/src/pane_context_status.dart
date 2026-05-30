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
        // The parent StatusbarHost wraps this item in Flexible(loose) so the
        // Row hands us a bounded maxWidth (T-160). ClideMarquee receives that
        // constraint via LayoutBuilder and scrolls when content exceeds it —
        // no ConstrainedBox(maxWidth) cap needed here.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            height: _slotHeight,
            child: ClideMarquee(child: widget),
          ),
        );
      },
    );
  }
}
