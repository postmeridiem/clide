import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
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

class ClideIconRail extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final item in items)
            _RailButton(
              item: item,
              active: item.id == activeId,
              onTap: () => onSelect(item.id),
            ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final ClideIconRailItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      button: true,
      selected: active,
      label: item.tooltip,
      child: ClideTappable(
        onTap: onTap,
        tooltip: item.tooltip,
        builder: (ctx, hovered, _) {
          final color = active
              ? tokens.globalForeground
              : hovered
                  ? tokens.sidebarForeground
                  : tokens.sidebarSectionHeader;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? tokens.tabActiveBorder : const Color(0x00000000),
                  width: 2,
                ),
              ),
            ),
            child: ClideIcon(item.icon, size: 16, color: color),
          );
        },
      ),
    );
  }
}
