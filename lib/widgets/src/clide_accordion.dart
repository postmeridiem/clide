import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/icons/phosphor.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

class ClideAccordion extends StatelessWidget {
  const ClideAccordion({
    super.key,
    required this.label,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.leading,
  });

  final String label;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClideTappable(
          onTap: onToggle,
          builder: (ctx, hovered, _) => Padding(
            padding: const EdgeInsets.only(left: 4, top: 10, bottom: 4),
            child: Row(
              children: [
                ClideIcon(expanded ? PhosphorIcons.caretDown : PhosphorIcons.caretRight, size: 10, color: tokens.globalTextMuted),
                const SizedBox(width: 6),
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                ClideText('$label · $count',
                    fontSize: clideFontSmall, color: hovered ? tokens.globalForeground : tokens.sidebarSectionHeader, fontFamily: clideMonoFamily),
              ],
            ),
          ),
        ),
        if (expanded) ...children,
      ],
    );
  }
}
