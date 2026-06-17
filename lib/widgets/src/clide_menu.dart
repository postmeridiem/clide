/// Menu content + reusable list-nav for clide popovers (D-88).
///
/// [ClideMenu] is the turnkey content for a [ClideAnchoredOverlay]: a
/// `dropdown`-token surface of selectable rows + separators, with arrow / enter
/// / escape navigation, optional mouse-hover highlight, an active mark, and
/// disabled rows. [ClideMenuListController] factors the skip-disabled / wrap
/// highlight logic so surfaces that keep bespoke rows (the typeaheads,
/// quick-open) reuse identical key handling without [ClideMenu]'s rendering.
library;

import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/icons/check.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Tracks the highlighted row across a navigable list, skipping rows for which
/// [isSelectable] is false (separators, disabled items). [length] is mutable so
/// live-filtered lists (typeaheads, quick-open) can resize without rebuilding.
class ClideMenuListController extends ChangeNotifier {
  ClideMenuListController({required this.isSelectable, required int length, this.wrap = true}) : _length = length;

  final bool Function(int index) isSelectable;
  final bool wrap;

  int _length;
  int get length => _length;
  set length(int value) {
    if (value == _length) return;
    _length = value;
    if (_highlight >= value) _highlight = -1;
    notifyListeners();
  }

  int _highlight = -1;
  int get highlighted => _highlight;

  void setHighlight(int index) {
    if (index == _highlight) return;
    _highlight = index;
    notifyListeners();
  }

  void reset() => setHighlight(-1);

  void moveNext() => _move(1);
  void movePrev() => _move(-1);

  List<int> get _navigable {
    final out = <int>[];
    for (var i = 0; i < _length; i++) {
      if (isSelectable(i)) out.add(i);
    }
    return out;
  }

  void _move(int dir) {
    final nav = _navigable;
    if (nav.isEmpty) return;
    final pos = nav.indexOf(_highlight);
    int next;
    if (pos < 0) {
      next = dir > 0 ? 0 : nav.length - 1;
    } else {
      next = pos + dir;
      if (next < 0 || next >= nav.length) {
        if (!wrap) return;
        next = (next + nav.length) % nav.length;
      }
    }
    setHighlight(nav[next]);
  }
}

/// A row or separator in a [ClideMenu].
sealed class ClideMenuEntry {
  const ClideMenuEntry();
}

/// A selectable menu row.
class ClideMenuItem extends ClideMenuEntry {
  const ClideMenuItem({
    required this.label,
    required this.onSelect,
    this.leading,
    this.trailing,
    this.active = false,
    this.enabled = true,
    this.color,
    this.keepOpenOnSelect = false,
    this.semanticLabel,
  });

  /// Leading glyph (per-mode icon, active check substitute, etc.).
  final ClideIconPainter? leading;
  final String label;

  /// Trailing widget (a keybinding label, say). When null and [active] is set,
  /// a check mark is drawn instead.
  final Widget? trailing;

  /// Marks the current selection (check mark + accent).
  final bool active;
  final bool enabled;

  /// Foreground tint for the row (per-mode colour). Defaults to dropdown fg.
  final Color? color;

  /// Keep the overlay open after selecting (e.g. a live-apply toggle).
  final bool keepOpenOnSelect;

  final VoidCallback onSelect;

  /// Overrides [label] for screen readers (e.g. proper-case vs lowercase).
  final String? semanticLabel;
}

/// A hairline divider between groups of items.
class ClideMenuSeparator extends ClideMenuEntry {
  const ClideMenuSeparator();
}

/// The turnkey popover content: renders [entries] on a dropdown-token surface
/// with keyboard + mouse navigation. Call [onClose] is invoked after a normal
/// (non-[ClideMenuItem.keepOpenOnSelect]) selection and on Escape.
class ClideMenu extends StatefulWidget {
  const ClideMenu({
    super.key,
    required this.entries,
    this.onClose,
    this.controller,
    this.minWidth = 220,
    this.maxWidth = 420,
    this.maxHeight,
    this.hoverHighlight = true,
    this.onArrowLeft,
    this.onArrowRight,
    this.autofocus = true,
  });

  final List<ClideMenuEntry> entries;

  /// Closes the host overlay. Called on normal select + Escape.
  final VoidCallback? onClose;

  /// Externally-owned nav controller. When null the menu creates its own.
  final ClideMenuListController? controller;

  final double minWidth;
  final double maxWidth;
  final double? maxHeight;

  /// Whether mouse hover moves the keyboard highlight (typeaheads disable this).
  final bool hoverHighlight;

  /// Optional left/right hooks (the menu bar switches top menus).
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowRight;

  final bool autofocus;

  @override
  State<ClideMenu> createState() => _ClideMenuState();
}

class _ClideMenuState extends State<ClideMenu> {
  final FocusNode _focus = FocusNode(debugLabel: 'clide-menu');
  late ClideMenuListController _ctrl;
  bool _ownsController = false;

  bool _selectable(int i) => widget.entries[i] is ClideMenuItem && (widget.entries[i] as ClideMenuItem).enabled;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? _makeController();
    _ownsController = widget.controller == null;
    _ctrl.addListener(_onCtrl);
    // Grab focus once mounted so arrow/enter/esc land here even inside a freshly
    // inserted overlay (autofocus alone is unreliable across overlay boundaries).
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  ClideMenuListController _makeController() => ClideMenuListController(isSelectable: _selectable, length: widget.entries.length);

  @override
  void didUpdateWidget(ClideMenu old) {
    super.didUpdateWidget(old);
    if (_ownsController && old.entries.length != widget.entries.length) {
      _ctrl.length = widget.entries.length;
    }
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrl);
    if (_ownsController) _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _activate(int index) {
    final entry = widget.entries[index];
    if (entry is! ClideMenuItem || !entry.enabled) return;
    entry.onSelect();
    if (!entry.keepOpenOnSelect) widget.onClose?.call();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _ctrl.moveNext();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _ctrl.movePrev();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.space:
        if (_ctrl.highlighted >= 0) _activate(_ctrl.highlighted);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onClose?.call();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        if (widget.onArrowLeft != null) {
          widget.onArrowLeft!();
          return KeyEventResult.handled;
        }
      case LogicalKeyboardKey.arrowRight:
        if (widget.onArrowRight != null) {
          widget.onArrowRight!();
          return KeyEventResult.handled;
        }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = ClideSettings.theme.of(context).surface;
    final col = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (var i = 0; i < widget.entries.length; i++) _row(i, widget.entries[i], t)],
    );
    return Focus(
      focusNode: _focus,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      child: IntrinsicWidth(
        child: Container(
          constraints: BoxConstraints(minWidth: widget.minWidth, maxWidth: widget.maxWidth, maxHeight: widget.maxHeight ?? double.infinity),
          decoration: BoxDecoration(
            color: t.dropdownBackground,
            border: Border.all(color: t.dropdownBorder),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: t.shadowAmbient, blurRadius: 12, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: widget.maxHeight != null ? SingleChildScrollView(child: col) : col,
        ),
      ),
    );
  }

  Widget _row(int index, ClideMenuEntry entry, SurfaceTokens t) {
    return switch (entry) {
      ClideMenuSeparator() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(height: 1, color: t.dividerColor),
      ),
      ClideMenuItem() => _itemRow(index, entry, t),
    };
  }

  Widget _itemRow(int index, ClideMenuItem item, SurfaceTokens t) {
    final highlighted = _ctrl.highlighted == index;
    final fg = item.enabled ? (item.color ?? t.dropdownForeground) : t.globalTextMuted;
    return Semantics(
      button: true,
      enabled: item.enabled,
      selected: item.active,
      label: item.semanticLabel ?? item.label,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: widget.hoverHighlight && item.enabled ? (_) => _ctrl.setHighlight(index) : null,
        child: ClideTappable(
          onTap: item.enabled ? () => _activate(index) : null,
          builder: (ctx, hovered, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: highlighted || (hovered && item.enabled) ? t.listItemHoverBackground : null,
            child: Row(
              children: [
                if (item.leading != null) ...[ClideIcon(item.leading!, size: 14, color: fg), const SizedBox(width: 8)],
                Expanded(
                  child: ClideText(item.label, fontSize: clideFontSmall, color: fg, maxLines: 1),
                ),
                if (item.trailing != null)
                  item.trailing!
                else if (item.active) ...[
                  const SizedBox(width: 8),
                  ClideIcon(const CheckIcon(), size: 12, color: item.color ?? t.globalFocus),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
