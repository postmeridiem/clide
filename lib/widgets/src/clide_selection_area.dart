import 'package:flutter/widgets.dart';

/// No-Material text selection wrapper (D-7 — clide ships no Material).
///
/// Flutter's convenient `SelectionArea` lives in `package:flutter/material.dart`,
/// so clide can't use it. This wraps the widget-layer [SelectableRegion]
/// with the desktop-appropriate setup: a managed [FocusNode], no on-screen
/// selection handles (`emptyTextSelectionControls` — desktop selects by
/// mouse drag), and [DefaultTextEditingShortcuts] so Ctrl/Cmd+A and
/// Ctrl/Cmd+C work even outside a `WidgetsApp`.
///
/// Any descendant `Text` / `Text.rich` (e.g. [ClideMarkdown],
/// [ClideCodeBlock] after T-135) becomes selectable, and selection +
/// copy span across them.
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

  @override
  Widget build(BuildContext context) {
    return DefaultTextEditingShortcuts(
      child: SelectableRegion(
        focusNode: _focusNode,
        selectionControls: emptyTextSelectionControls,
        child: widget.child,
      ),
    );
  }
}
