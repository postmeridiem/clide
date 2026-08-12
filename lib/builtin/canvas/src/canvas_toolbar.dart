/// The canvas pane's floating edit toolbar (T-322).
///
/// Floats over the canvas rather than taking a strip of its height, and is
/// dragged by its grip. Position is deliberately **not** persisted — it
/// resets with the document, so there's no per-document/per-workspace scope
/// to get wrong and no "reset position" escape hatch to design. It is still
/// clamped to the pane, because a pane that shrinks while the toolbar sits
/// near an edge would otherwise strand it out of reach for the session.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Outer size of the toolbar, and the inset it parks at.
const double canvasToolbarWidth = 34;
const double canvasToolbarInset = 12;
const double canvasToolbarPadding = 4;

/// Height of the grip strip at the top of the toolbar. Only this band drags —
/// making the whole body draggable would move the toolbar on every mis-click
/// of a button.
const double canvasToolbarGripHeight = 12;

/// The draggable band of a toolbar parked at [pos], pane-local.
///
/// The *view* owns this hit test rather than the toolbar owning a
/// GestureDetector: the canvas already has a pan recognizer covering the
/// whole pane, and two competing recognizers make which one wins a matter of
/// gesture-arena ordering. One owner, one answer.
Rect canvasToolbarGripRect(Offset pos) => Rect.fromLTWH(pos.dx, pos.dy, canvasToolbarWidth, canvasToolbarPadding + canvasToolbarGripHeight);

/// One action in [CanvasToolbar].
@immutable
class CanvasToolbarAction {
  const CanvasToolbarAction({required this.glyph, required this.label, required this.onPressed});

  /// Phosphor glyph name.
  final String glyph;

  /// Tooltip + semantics label, already localized.
  final String label;

  /// Null disables the button (e.g. Delete with nothing selected).
  final VoidCallback? onPressed;
}

/// Clamp [pos] so the whole toolbar stays inside a [paneSize] pane.
Offset clampCanvasToolbar(Offset pos, Size paneSize, int actionCount) {
  final height = canvasToolbarHeight(actionCount);
  final maxX = (paneSize.width - canvasToolbarWidth).clamp(0.0, double.infinity);
  final maxY = (paneSize.height - height).clamp(0.0, double.infinity);
  return Offset(pos.dx.clamp(0.0, maxX), pos.dy.clamp(0.0, maxY));
}

/// Grip + one 24px row per action, plus the padding on each side.
double canvasToolbarHeight(int actionCount) => (canvasToolbarPadding * 2) + canvasToolbarGripHeight + (actionCount * 26);

class CanvasToolbar extends StatelessWidget {
  const CanvasToolbar({super.key, required this.actions});

  final List<CanvasToolbarAction> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Container(
      width: canvasToolbarWidth,
      padding: const EdgeInsets.all(canvasToolbarPadding),
      decoration: BoxDecoration(
        // Elevated chrome floating over the canvas — opaque on purpose, so
        // a node passing underneath doesn't show through the buttons.
        color: tokens.panelHeader,
        border: Border.all(color: tokens.panelBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Visual only — the drag itself is handled by the view, which
          // hit-tests [canvasToolbarGripRect].
          MouseRegion(
            cursor: SystemMouseCursors.move,
            child: SizedBox(
              height: canvasToolbarGripHeight,
              width: double.infinity,
              child: Center(child: ClideIcon(PhosphorIcons.byName('dots-six'), size: 10, color: tokens.globalTextMuted)),
            ),
          ),
          for (final a in actions) _ToolbarButton(action: a),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.action});

  final CanvasToolbarAction action;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final enabled = action.onPressed != null;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: action.label,
        child: ClideTappable(
          onTap: action.onPressed,
          tooltip: action.label,
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          builder: (context, hovered, pressed) {
            final Color fg;
            if (!enabled) {
              fg = tokens.globalTextMuted;
            } else {
              fg = hovered ? tokens.globalForeground : tokens.globalTextMuted;
            }
            return Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: enabled && hovered ? tokens.listItemHoverBackground : null, borderRadius: BorderRadius.circular(4)),
              child: Center(child: ClideIcon(PhosphorIcons.byName(action.glyph), size: 14, color: fg)),
            );
          },
        ),
      ),
    );
  }
}
