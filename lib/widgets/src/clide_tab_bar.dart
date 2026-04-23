import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:clide/widgets/src/clide_text.dart';
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

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.active, required this.onTap});

  final ClideTabItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final fg = active ? tokens.tabActiveForeground : tokens.tabInactiveForeground;

    return Semantics(
      button: true,
      selected: active,
      label: item.title,
      onTap: onTap,
      excludeSemantics: true,
      child: ClideTappable(
        onTap: onTap,
        builder: (context, hovered, _) {
          final bg = active ? tokens.tabActive : tokens.tabInactive;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                bottom: BorderSide(
                  color: active ? tokens.tabActiveBorder : const Color(0x00000000),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon != null) ...[
                  ClideIcon(item.icon!, size: 12, color: fg),
                  const SizedBox(width: 6),
                ],
                ClideText(item.title, color: fg),
              ],
            ),
          );
        },
      ),
    );
  }
}
