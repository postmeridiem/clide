/// Field-anchored suggestion list for text typeaheads (D-88).
///
/// The host owns the text parsing + completion (where the `@`/`/` token is, how
/// to filter, how to rewrite the text on select); `ClideTypeahead` owns the
/// anchored overlay + the suggestion list. It is driven by [suggestions] —
/// non-empty shows the popover above the field, empty hides it. Unlike a menu,
/// it does NOT capture focus or install a tap-away barrier: the text field keeps
/// focus (you're still typing), and the host closes it on text change / blur /
/// Esc. Pass [navController] to drive the highlight from the field's own key
/// handler (the slash typeahead does this while the EditableText keeps focus);
/// omit it for a mouse-only list (the @-mention).
library;

import 'package:clide/widgets/src/clide_anchored.dart';
import 'package:clide/widgets/src/clide_menu.dart';
import 'package:flutter/widgets.dart';

class ClideTypeahead extends StatefulWidget {
  const ClideTypeahead({
    super.key,
    required this.child,
    required this.suggestions,
    required this.onSelect,
    this.navController,
    this.maxWidth = 320,
    this.formatLabel,
  });

  /// The text field (the anchor). Suggestions float above it.
  final Widget child;

  /// Current suggestions; empty hides the popover.
  final List<String> suggestions;

  /// Called with the raw suggestion value when a row is chosen.
  final ValueChanged<String> onSelect;

  /// External highlight controller — drive it from the field's key handler for
  /// keyboard nav while the field keeps focus. Null = mouse-only (hover) list.
  final ClideMenuListController? navController;

  final double maxWidth;

  /// Maps a raw suggestion to its display label (e.g. `'/$cmd'`, `'@$name'`).
  final String Function(String value)? formatLabel;

  @override
  State<ClideTypeahead> createState() => _ClideTypeaheadState();
}

class _ClideTypeaheadState extends State<ClideTypeahead> {
  final ClideOverlayController _overlay = ClideOverlayController();

  @override
  void initState() {
    super.initState();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(ClideTypeahead old) {
    super.didUpdateWidget(old);
    _scheduleSync();
  }

  // Drive open/close off the suggestion list, post-frame — opening inserts an
  // OverlayEntry, which is illegal during the parent's build.
  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.suggestions.isEmpty) {
        _overlay.close();
      } else {
        _overlay.open();
      }
    });
  }

  @override
  void dispose() {
    _overlay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClideAnchoredOverlay(
      controller: _overlay,
      side: ClideAnchorSide.above,
      align: ClideAnchorAlign.start,
      offset: const Offset(0, -4),
      barrier: false, // closes on text change / blur, not a tap-away barrier
      captureFocus: false, // the text field keeps focus
      dismissOnEscape: false, // the host routes Esc
      anchor: widget.child,
      overlayBuilder: (ctx, ctrl) => ClideMenu(
        autofocus: false,
        hoverHighlight: widget.navController == null,
        controller: widget.navController,
        minWidth: 0,
        maxWidth: widget.maxWidth,
        entries: [
          for (final s in widget.suggestions) ClideMenuItem(label: widget.formatLabel?.call(s) ?? s, onSelect: () => widget.onSelect(s)),
        ],
      ),
    );
  }
}
