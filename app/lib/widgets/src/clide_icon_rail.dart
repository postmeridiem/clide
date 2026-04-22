import 'package:clide_app/kernel/src/theme/controller.dart';
import 'package:clide_app/widgets/src/clide_icon.dart';
import 'package:clide_app/widgets/src/clide_tooltip.dart';
import 'package:flutter/widgets.dart';

class ClideIconRailItem {
  const ClideIconRailItem({
    required this.id,
    required this.icon,
    required this.tooltip,
  });

  final String id;
  final ClideIconPainter icon;
  final String tooltip;
}

class ClideIconRail extends StatefulWidget {
  const ClideIconRail({
    super.key,
    required this.items,
    required this.activeId,
    required this.onSelect,
  });

  final List<ClideIconRailItem> items;
  final String? activeId;
  final ValueChanged<String> onSelect;

  @override
  State<ClideIconRail> createState() => _ClideIconRailState();
}

class _ClideIconRailState extends State<ClideIconRail> {
  String? _hoveredId;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return MouseRegion(
      onExit: (_) => setState(() => _hoveredId = null),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.dividerColor)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final item in widget.items)
              _RailButton(
                item: item,
                active: item.id == widget.activeId,
                hovered: item.id == _hoveredId,
                onHover: () => setState(() => _hoveredId = item.id),
                onTap: () => widget.onSelect(item.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.active,
    required this.hovered,
    required this.onHover,
    required this.onTap,
  });

  final ClideIconRailItem item;
  final bool active;
  final bool hovered;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final color = active
        ? tokens.globalForeground
        : hovered
            ? tokens.sidebarForeground
            : tokens.sidebarSectionHeader;

    return Semantics(
      button: true,
      selected: active,
      label: item.tooltip,
      child: ClideTooltip(
        message: item.tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onHover(),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active
                        ? tokens.tabActiveBorder
                        : const Color(0x00000000),
                    width: 2,
                  ),
                ),
              ),
              child: ClideIcon(item.icon, size: 16, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
