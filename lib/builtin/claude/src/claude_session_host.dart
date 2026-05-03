import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'claude_pane.dart';

class ClaudeSessionHost extends StatefulWidget {
  const ClaudeSessionHost({super.key});

  @override
  State<ClaudeSessionHost> createState() => ClaudeSessionHostState();
}

class ClaudeSessionHostState extends State<ClaudeSessionHost> {
  final List<_Session> _sessions = [];
  int _activeIndex = 0;
  int _nextSecondary = 1;

  @override
  void initState() {
    super.initState();
    _sessions.add(_Session(isPrimary: true, label: 'primary'));
  }

  void addSecondary() {
    final index = _nextSecondary++;
    setState(() {
      _sessions.add(_Session(isPrimary: false, secondaryIndex: index, label: 'session $index'));
      _activeIndex = _sessions.length - 1;
    });
  }

  void _close(int index) {
    if (index < 0 || index >= _sessions.length) return;
    if (_sessions[index].isPrimary) return;
    setState(() {
      _sessions.removeAt(index);
      if (_activeIndex >= _sessions.length) _activeIndex = _sessions.length - 1;
      if (_activeIndex < 0) _activeIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final showTabs = _sessions.length > 1;

    return Column(
      children: [
        if (showTabs)
          _TabRow(
            sessions: _sessions,
            activeIndex: _activeIndex,
            tokens: tokens,
            onSelect: (i) => setState(() => _activeIndex = i),
            onClose: _close,
            onAdd: addSecondary,
          ),
        Expanded(
          child: IndexedStack(
            index: _activeIndex,
            children: [
              for (final s in _sessions)
                ClaudePane(
                  key: s.key,
                  isPrimary: s.isPrimary,
                  secondaryIndex: s.secondaryIndex,
                  showChrome: !showTabs,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Session {
  _Session({required this.isPrimary, this.secondaryIndex, required this.label}) : key = GlobalKey();
  final bool isPrimary;
  final int? secondaryIndex;
  final String label;
  final GlobalKey key;
}

class _TabRow extends StatelessWidget {
  const _TabRow({
    required this.sessions,
    required this.activeIndex,
    required this.tokens,
    required this.onSelect,
    required this.onClose,
    required this.onAdd,
  });

  final List<_Session> sessions;
  final int activeIndex;
  final SurfaceTokens tokens;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onAdd,
      child: Container(
        height: 28,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.dividerColor))),
        child: Row(
          children: [
            for (var i = 0; i < sessions.length; i++)
              _Tab(
                  session: sessions[i],
                  active: i == activeIndex,
                  tokens: tokens,
                  onTap: () => onSelect(i),
                  onClose: sessions[i].isPrimary ? null : () => onClose(i)),
            const SizedBox(width: 4),
            _AddButton(tokens: tokens, onTap: onAdd),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.session, required this.active, required this.tokens, required this.onTap, this.onClose});
  final _Session session;
  final bool active;
  final SurfaceTokens tokens;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hovered && !active ? tokens.tabInactive : null,
          border: Border(bottom: BorderSide(color: active ? tokens.tabActiveBorder : const Color(0x00000000), width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClideText(
              session.label,
              fontSize: 12,
              color: active ? tokens.tabActiveForeground : tokens.tabInactiveForeground,
              fontFamily: clideMonoFamily,
            ),
            if (onClose != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClose,
                child: ClideIcon(PhosphorIcons.xMark, size: 10, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.tokens, required this.onTap});
  final SurfaceTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      onTap: onTap,
      tooltip: 'New session',
      builder: (context, hovered, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: ClideText('+', fontSize: 14, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
      ),
    );
  }
}
