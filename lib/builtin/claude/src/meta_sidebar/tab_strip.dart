/// The Activity / Team / Config sub-tab strip — same interaction as the pql
/// panel's view tabs, with an underline under the active tab. Split out of
/// claude_meta_sidebar.dart (T-395).
library;

import 'package:clide/builtin/claude/src/meta_sidebar/models.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class SidebarTabStrip extends StatelessWidget {
  const SidebarTabStrip({super.key, required this.current, required this.memberCount, required this.onPick});
  final SidebarTab current;
  final int memberCount;
  final ValueChanged<SidebarTab> onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.panelBorder)),
      ),
      child: Row(
        children: [
          for (final t in SidebarTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Semantics(
                button: true,
                selected: t == current,
                label: _label(t),
                excludeSemantics: true,
                onTap: () => onPick(t),
                child: ClideTappable(
                  onTap: () => onPick(t),
                  builder: (ctx, hovered, _) => Container(
                    padding: const EdgeInsets.only(bottom: 3),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: t == current ? tokens.globalFocus : const Color(0x00000000), width: 2)),
                    ),
                    child: ClideText(_label(t), fontSize: clideFontSmall, color: t == current || hovered ? tokens.globalForeground : tokens.globalTextMuted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _label(SidebarTab t) => switch (t) {
    SidebarTab.activity => 'Activity',
    SidebarTab.team => memberCount == 0 ? 'Team' : 'Team · $memberCount',
    SidebarTab.config => 'Config',
  };
}
