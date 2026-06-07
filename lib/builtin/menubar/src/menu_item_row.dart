import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'menu_model.dart';

/// One command row in an open menu (T-48): label on the left, inline keybinding
/// on the right (two-column control pattern). Disabled items render greyed and
/// inert; the keyboard-highlighted row uses the hover background.
class MenuItemRow extends StatelessWidget {
  const MenuItemRow({super.key, required this.item, required this.highlighted, required this.onActivate});

  final ResolvedItem item;
  final bool highlighted;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final enabled = item.enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: item.title,
      child: ClideTappable(
        onTap: enabled ? onActivate : null,
        builder: (context, hovered, _) => Container(
          color: enabled && (highlighted || hovered) ? tokens.listItemHoverBackground : null,
          padding: const EdgeInsets.symmetric(horizontal: clideInsetText, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: ClideText(
                  item.title,
                  fontSize: clideFontCaption,
                  color: enabled ? tokens.dropdownForeground : tokens.globalTextMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.keybinding != null) ...[
                const SizedBox(width: clideGapSection),
                ClideText(item.keybinding!, fontSize: clideFontSmall, fontFamily: clideMonoFamily, color: tokens.globalTextMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
