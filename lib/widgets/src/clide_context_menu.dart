/// Pointer-anchored context menu (D-109).
///
/// [ClideAnchoredOverlay] (D-88) positions a popover against a *widget*, via a
/// `LayerLink` onto that widget's box. A context menu has no anchor widget — it
/// opens wherever the pointer was — so it cannot use that path and owns the
/// small parallel one here: a [ContextMenuController] insert into the root
/// overlay, a tap-away barrier, and edge-flip so a right-click near the
/// bottom-right corner still shows the whole menu.
///
/// Content is a plain [ClideMenu], which already brings the dropdown-token
/// surface, arrow/enter navigation and Escape-to-close.
library;

import 'dart:math' as math;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/src/clide_menu.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Opens a [ClideMenu] at a global pointer position.
///
/// One menu at a time process-wide — [ContextMenuController] enforces that, so
/// opening a second dismisses the first.
abstract final class ClideContextMenu {
  static final ContextMenuController _controller = ContextMenuController();

  /// Whether a context menu is currently on screen.
  static bool get isShown => _controller.isShown;

  /// Dismisses the menu, if one is showing.
  static void hide() {
    if (_controller.isShown) _controller.remove();
  }

  /// Opens [entries] at [globalPosition].
  ///
  /// A no-op when [entries] is empty, so callers can filter down to the actions
  /// that actually apply without also guarding the call.
  static void show(BuildContext context, {required Offset globalPosition, required List<ClideMenuEntry> entries}) {
    if (entries.isEmpty) return;
    _controller.show(
      context: context,
      contextMenuBuilder: (ctx) => ClideContextMenuSurface(globalPosition: globalPosition, entries: entries, onClose: hide),
    );
  }
}

/// The overlay body: a tap-away barrier behind an edge-flipped [ClideMenu].
///
/// Public because `contextMenuBuilder` callbacks (on `EditableText` and
/// `SelectableRegion`) are handed a builder slot rather than calling
/// [ClideContextMenu.show], and need the same surface.
class ClideContextMenuSurface extends StatelessWidget {
  const ClideContextMenuSurface({super.key, required this.globalPosition, required this.entries, required this.onClose, this.viewportPadding = 8});

  /// Where the pointer was, in global coordinates.
  final Offset globalPosition;

  final List<ClideMenuEntry> entries;

  /// Dismisses the menu. Called on select, Escape, and tap-away.
  final VoidCallback onClose;

  /// Minimum gap kept between the menu and the viewport edge.
  final double viewportPadding;

  @override
  Widget build(BuildContext context) {
    // The overlay fills the window but is not guaranteed to start at its
    // origin, so map the pointer into the overlay's own coordinate space —
    // which is what the layout delegate below measures against.
    final overlayBox = Overlay.of(context).context.findRenderObject();
    final anchor = overlayBox is RenderBox && overlayBox.hasSize ? overlayBox.globalToLocal(globalPosition) : globalPosition;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose, onSecondaryTap: onClose),
        ),
        CustomSingleChildLayout(
          delegate: _PointerAnchorLayout(anchor: anchor, padding: viewportPadding),
          child: ClideMenu(entries: entries, onClose: onClose),
        ),
      ],
    );
  }
}

/// Maps the [ContextMenuButtonItem]s Flutter computes for a text field or a
/// selectable region onto [ClideMenuItem]s.
///
/// Both `EditableTextState` and `SelectableRegionState` expose the same list,
/// already filtered to the actions that apply to the current selection and
/// clipboard — so what clide owns is presentation (localised label, shortcut
/// hint), not the decision about which entries to offer.
///
/// Dismissal is [ClideMenu]'s own: selecting a row invokes its `onClose`.
List<ClideMenuEntry> clideContextMenuEntries(BuildContext context, List<ContextMenuButtonItem> items) {
  final muted = ClideSettings.theme.of(context).surface.globalTextMuted;
  final mono = ClideSettings.fonts.monoOf(context);
  final out = <ClideMenuEntry>[];
  for (final item in items) {
    final shortcut = _buttonShortcut(item.type);
    out.add(
      ClideMenuItem(
        // A `custom` item (the OS text-processing actions) carries its own
        // label and has no clide string to look up.
        label: item.label ?? _buttonLabel(context, item.type),
        enabled: item.onPressed != null,
        trailing: shortcut == null ? null : ClideText(shortcut, fontSize: clideFontSmall, fontFamily: mono, color: muted),
        onSelect: () => item.onPressed?.call(),
      ),
    );
  }
  return out;
}

String _buttonLabel(BuildContext context, ContextMenuButtonType type) {
  final (key, fallback) = switch (type) {
    ContextMenuButtonType.cut => ('contextMenu.cut', 'Cut'),
    ContextMenuButtonType.copy => ('contextMenu.copy', 'Copy'),
    ContextMenuButtonType.paste => ('contextMenu.paste', 'Paste'),
    ContextMenuButtonType.selectAll => ('contextMenu.selectAll', 'Select all'),
    ContextMenuButtonType.delete => ('contextMenu.delete', 'Delete'),
    ContextMenuButtonType.lookUp => ('contextMenu.lookUp', 'Look up'),
    ContextMenuButtonType.searchWeb => ('contextMenu.searchWeb', 'Search web'),
    ContextMenuButtonType.share => ('contextMenu.share', 'Share'),
    ContextMenuButtonType.liveTextInput => ('contextMenu.liveTextInput', 'Scan text'),
    ContextMenuButtonType.custom => ('contextMenu.custom', 'Action'),
  };
  return ClideSettings.i18n.string(context, key, namespace: 'core', placeholder: fallback);
}

/// The hint shown on the right of a row. Only the four clipboard verbs have a
/// binding worth advertising; the rest render without one.
String? _buttonShortcut(ContextMenuButtonType type) {
  final key = switch (type) {
    ContextMenuButtonType.cut => LogicalKeyboardKey.keyX,
    ContextMenuButtonType.copy => LogicalKeyboardKey.keyC,
    ContextMenuButtonType.paste => LogicalKeyboardKey.keyV,
    ContextMenuButtonType.selectAll => LogicalKeyboardKey.keyA,
    _ => null,
  };
  if (key == null) return null;
  final primary = defaultTargetPlatform == TargetPlatform.macOS ? KeyModifier.meta : KeyModifier.ctrl;
  return KeyChord(modifiers: {primary}, key: key).display;
}

/// Places the menu down-and-right of the pointer, flipping to the other side of
/// it when that would overflow, then clamping into the padded viewport.
class _PointerAnchorLayout extends SingleChildLayoutDelegate {
  const _PointerAnchorLayout({required this.anchor, required this.padding});

  final Offset anchor;
  final double padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // Loose, so the menu still shrink-wraps its rows, but capped to the padded
    // viewport so an unusually long one cannot paint outside the window.
    return BoxConstraints.loose(Size(math.max(0, constraints.maxWidth - padding * 2), math.max(0, constraints.maxHeight - padding * 2)));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = anchor.dx;
    if (x + childSize.width + padding > size.width) x = anchor.dx - childSize.width;
    var y = anchor.dy;
    if (y + childSize.height + padding > size.height) y = anchor.dy - childSize.height;
    return Offset(_clamp(x, size.width, childSize.width), _clamp(y, size.height, childSize.height));
  }

  /// Keeps the menu inside the padded viewport, tolerating the degenerate case
  /// of a child larger than the space available (the upper bound wins).
  double _clamp(double value, double extent, double childExtent) {
    return value.clamp(padding, math.max(padding, extent - childExtent - padding));
  }

  @override
  bool shouldRelayout(_PointerAnchorLayout old) => old.anchor != anchor || old.padding != padding;
}
