import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:flutter/widgets.dart';

class ClideIconRailItem {
  const ClideIconRailItem({required this.id, required this.icon, required this.tooltip, this.iconColor});

  final String id;
  final ClideIconPainter icon;
  final String tooltip;

  /// Brand/identity tint for this tab's icon (e.g. the Claude accent on the
  /// Claude tab, T-418). Shown full-strength when active/hovered and slightly
  /// dimmed when idle; null keeps the normal state colours.
  final Color? iconColor;
}

/// A trailing rail entry that is **not a tab**: it carries its own on/off state
/// and toggles something instead of selecting a view (T-528).
///
/// The rail's [ClideIconRail.activeId] models exactly one selected item, which
/// is right for tabs and wrong for this — a toggle is on or off independently of
/// which view is showing, so two things in the rail can read as "on" at once.
///
/// Drawn identically to a tab on purpose. It sits at the end of the same rail
/// and should read as the last member of that family; only its behaviour
/// differs.
class ClideIconRailToggle {
  const ClideIconRailToggle({required this.id, required this.icon, required this.tooltip, required this.on, required this.onToggle, this.iconColor});

  final String id;
  final ClideIconPainter icon;

  /// Should describe the *action*, since the state is already conveyed by the
  /// button's appearance and by its `toggled` semantics.
  final String tooltip;

  final bool on;
  final ValueChanged<bool> onToggle;
  final Color? iconColor;
}

class ClideIconRail extends StatelessWidget {
  const ClideIconRail({super.key, required this.items, required this.activeId, required this.onSelect, this.toggles = const []});

  final List<ClideIconRailItem> items;
  final String? activeId;
  final ValueChanged<String> onSelect;

  /// Non-tab entries rendered after [items]. See [ClideIconRailToggle].
  final List<ClideIconRailToggle> toggles;

  @override
  Widget build(BuildContext context) {
    // Center the icons when they fit; scroll horizontally when there are
    // more tabs than the rail is wide. The ConstrainedBox minWidth keeps
    // them centered while there's room but doesn't cap growth, so the
    // ScrollView takes over instead of the Row overflowing.
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final item in items) _RailButton(item: item, active: item.id == activeId, onTap: () => onSelect(item.id)),
                for (final t in toggles)
                  _RailButton(
                    item: ClideIconRailItem(id: t.id, icon: t.icon, tooltip: t.tooltip, iconColor: t.iconColor),
                    active: t.on,
                    toggle: true,
                    onTap: () => t.onToggle(!t.on),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.item, required this.active, required this.onTap, this.toggle = false});

  final ClideIconRailItem item;
  final bool active;
  final VoidCallback onTap;

  /// Changes only what a screen reader is told (D-20). A tab is *selected* —
  /// one of a set, and picking it deselects its neighbour. A toggle is
  /// *toggled* — on or off, independently of everything beside it. Announcing
  /// the second as the first would tell a reader that turning Clide on had
  /// switched away from the current view.
  final bool toggle;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Semantics(
      button: true,
      selected: toggle ? null : active,
      toggled: toggle ? active : null,
      label: item.tooltip,
      child: ClideTappable(
        onTap: onTap,
        tooltip: item.tooltip,
        builder: (ctx, hovered, _) {
          final tint = item.iconColor;
          final color = tint != null
              ? (active || hovered ? tint : tint.withValues(alpha: 0.7))
              : active
              ? tokens.globalForeground
              : hovered
              ? tokens.sidebarForeground
              : tokens.sidebarSectionHeader;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: active ? tokens.tabActiveBorder : const Color(0x00000000), width: 2)),
            ),
            child: ClideIcon(item.icon, size: 16, color: color),
          );
        },
      ),
    );
  }
}
