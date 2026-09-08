import 'package:clide/widgets/src/clide_context_menu.dart';
import 'package:flutter/widgets.dart';

/// No-Material text selection wrapper (D-7 — clide ships no Material).
///
/// Flutter's convenient `SelectionArea` lives in `package:flutter/material.dart`,
/// so clide can't use it. This wraps the widget-layer [SelectableRegion]
/// with the desktop-appropriate setup: a managed [FocusNode],
/// [DefaultTextEditingShortcuts] so Ctrl/Cmd+A and Ctrl/Cmd+C work even
/// outside a `WidgetsApp`, and a right-click menu (D-109).
///
/// Any descendant `Text` / `Text.rich` (e.g. [ClideMarkdown],
/// [ClideCodeBlock] after T-135) becomes selectable, and selection +
/// copy span across them.
///
/// The controls are clide's own [_NoHandleControls] rather than Flutter's
/// `emptyTextSelectionControls`, which this used to pass. The two draw
/// identically — nothing — but `emptyTextSelectionControls` does not mix in
/// `TextSelectionHandleControls`, and [SelectableRegion] reads that mixin as
/// "legacy toolbar" and **ignores `contextMenuBuilder`** for backwards
/// compatibility. Flutter's own docs call it "a placeholder… not practical for
/// production… no context menus on desktop"; passing it is what left clide
/// without a right-click menu here.
/// Draws no handles (desktop selects by mouse, so handles are noise) while
/// still satisfying [SelectableRegion]'s `TextSelectionHandleControls` check,
/// which is what gates `contextMenuBuilder`.
class _NoHandleControls extends EmptyTextSelectionControls with TextSelectionHandleControls {}

final _noHandleControls = _NoHandleControls();

class ClideSelectionArea extends StatefulWidget {
  const ClideSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  State<ClideSelectionArea> createState() => _ClideSelectionAreaState();
}

class _ClideSelectionAreaState extends State<ClideSelectionArea> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'ClideSelectionArea');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Widget _contextMenu(BuildContext context, SelectableRegionState state) {
    return ClideContextMenuSurface(
      globalPosition: state.contextMenuAnchors.primaryAnchor,
      entries: clideContextMenuEntries(context, state.contextMenuButtonItems),
      onClose: state.hideToolbar,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextEditingShortcuts(
      child: SelectableRegion(focusNode: _focusNode, selectionControls: _noHandleControls, contextMenuBuilder: _contextMenu, child: widget.child),
    );
  }
}
