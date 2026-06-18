/// The Activity / Team / Config sub-tab strip — same interaction as the pql
/// panel's view tabs, with an underline under the active tab. Split out of
/// claude_meta_sidebar.dart (T-395).
library;

import 'package:clide/builtin/claude/src/meta_sidebar/models.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class SidebarTabStrip extends StatelessWidget {
  const SidebarTabStrip({super.key, required this.current, required this.memberCount, required this.onPick});
  final SidebarTab current;
  final int memberCount;
  final ValueChanged<SidebarTab> onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
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
                label: _label(context, t),
                excludeSemantics: true,
                onTap: () => onPick(t),
                child: ClideTappable(
                  onTap: () => onPick(t),
                  builder: (ctx, hovered, _) => Container(
                    padding: const EdgeInsets.only(bottom: 3),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: t == current ? tokens.globalFocus : const Color(0x00000000), width: 2)),
                    ),
                    child: ClideText(
                      _label(context, t),
                      fontSize: clideFontSmall,
                      color: t == current || hovered ? tokens.globalForeground : tokens.globalTextMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _label(BuildContext context, SidebarTab t) => switch (t) {
    SidebarTab.activity => ClideSettings.i18n.string(context, 'tabStrip.activity', namespace: 'builtin.claude', placeholder: 'Activity'),
    SidebarTab.team =>
      memberCount == 0
          ? ClideSettings.i18n.string(context, 'tabStrip.team', namespace: 'builtin.claude', placeholder: 'Team')
          : ClideSettings.i18n.interpolated(
              context,
              'tabStrip.team.count',
              namespace: 'builtin.claude',
              placeholder: 'Team · $memberCount',
              replacers: [I18nReplacer(from: '{count}', replace: '$memberCount')],
            ),
    SidebarTab.config => ClideSettings.i18n.string(context, 'tabStrip.config', namespace: 'builtin.claude', placeholder: 'Config'),
  };
}
