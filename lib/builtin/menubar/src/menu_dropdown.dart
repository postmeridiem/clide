import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'menu_item_row.dart';
import 'menu_model.dart';

/// The open-menu panel (T-48): a `dropdown`-token surface listing the resolved
/// items, with full keyboard navigation (Up/Down skip disabled rows +
/// separators, Enter activates, Esc closes, Left/Right switch top menus).
class MenuDropdown extends StatefulWidget {
  const MenuDropdown({
    super.key,
    required this.menu,
    required this.onActivate,
    required this.onClose,
    required this.onPrevMenu,
    required this.onNextMenu,
  });

  final ResolvedMenu menu;
  final void Function(String commandId) onActivate;
  final VoidCallback onClose;
  final VoidCallback onPrevMenu;
  final VoidCallback onNextMenu;

  @override
  State<MenuDropdown> createState() => _MenuDropdownState();
}

class _MenuDropdownState extends State<MenuDropdown> {
  final FocusNode _focus = FocusNode(debugLabel: 'menu-dropdown');
  int _highlight = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Indices into `menu.items` that are enabled command rows (navigable).
  List<int> get _navigable {
    final out = <int>[];
    for (var i = 0; i < widget.menu.items.length; i++) {
      final it = widget.menu.items[i];
      if (it is ResolvedItem && it.enabled) out.add(i);
    }
    return out;
  }

  void _move(int dir) {
    final nav = _navigable;
    if (nav.isEmpty) return;
    final pos = nav.indexOf(_highlight);
    final next = pos < 0 ? (dir > 0 ? 0 : nav.length - 1) : (pos + dir) % nav.length;
    setState(() => _highlight = nav[(next + nav.length) % nav.length]);
  }

  void _activateHighlighted() {
    if (_highlight < 0) return;
    final it = widget.menu.items[_highlight];
    if (it is ResolvedItem && it.enabled) widget.onActivate(it.commandId);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.space:
        _activateHighlighted();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onClose();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        widget.onPrevMenu();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        widget.onNextMenu();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: IntrinsicWidth(
        child: Container(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
          decoration: BoxDecoration(
            color: tokens.dropdownBackground,
            border: Border.all(color: tokens.dropdownBorder),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: tokens.shadowAmbient, blurRadius: 12, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.menu.items.length; i++) _row(i, widget.menu.items[i], tokens),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(int index, ResolvedNode node, SurfaceTokens tokens) {
    return switch (node) {
      ResolvedSeparator() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(height: 1, color: tokens.dividerColor),
        ),
      ResolvedItem() => MenuItemRow(
          item: node,
          highlighted: index == _highlight,
          onActivate: () => widget.onActivate(node.commandId),
        ),
    };
  }
}
