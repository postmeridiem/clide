import 'package:clide_app/kernel/src/theme/controller.dart';
import 'package:clide_app/widgets/src/clide_icon.dart';
import 'package:clide_app/widgets/src/clide_text.dart';
import 'package:flutter/widgets.dart';

@immutable
class ClideTabItem {
  const ClideTabItem({
    required this.id,
    required this.title,
    this.icon,
  });

  final String id;
  final String title;
  final ClideIconPainter? icon;
}

class ClideTabBar extends StatelessWidget {
  const ClideTabBar({
    super.key,
    required this.items,
    required this.activeId,
    required this.onSelect,
    this.height = 28,
    this.semanticContainerLabel,
  });

  final List<ClideTabItem> items;
  final String? activeId;
  final ValueChanged<String> onSelect;
  final double height;

  /// Optional container-level label for screen readers (e.g. "Sidebar tabs").
  final String? semanticContainerLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      container: true,
      label: semanticContainerLabel,
      explicitChildNodes: true,
      child: Container(
        height: height,
        color: tokens.tabBarBackground,
        child: Row(
          children: [
            for (final item in items)
              _Tab(
                item: item,
                active: item.id == activeId,
                onTap: () => onSelect(item.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({required this.item, required this.active, required this.onTap});

  final ClideTabItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final bg = widget.active
        ? tokens.tabActive
        : (_hovered ? tokens.tabInactive : tokens.tabInactive);
    final fg = widget.active
        ? tokens.tabActiveForeground
        : tokens.tabInactiveForeground;

    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.item.title,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                bottom: BorderSide(
                  color: widget.active
                      ? tokens.tabActiveBorder
                      : const Color(0x00000000),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.item.icon != null) ...[
                  ClideIcon(widget.item.icon!, size: 12, color: fg),
                  const SizedBox(width: 6),
                ],
                ClideText(widget.item.title, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
