/// Claude's task list, docked above the composer (T-308).
///
/// A compact, display-only surface (D-78 — not an interactive control) pinned
/// between the conversation and the composer so the user can always see what
/// Claude is tracking and how far along it is. Collapsed by default to a
/// one-line summary (`N tasks · M done` + the current in-progress item);
/// tapping expands the full checklist. Renders nothing when there are no tasks.
library;

import 'package:clide/builtin/claude/src/task_list.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ClaudeTaskDock extends StatefulWidget {
  const ClaudeTaskDock({super.key, required this.tasks});

  final List<TaskItem> tasks;

  @override
  State<ClaudeTaskDock> createState() => _ClaudeTaskDockState();
}

class _ClaudeTaskDockState extends State<ClaudeTaskDock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    if (tasks.isEmpty) return const SizedBox.shrink(); // no chrome when empty

    final tokens = ClideSettings.theme.of(context).surface;
    final done = tasks.where((t) => t.status == TaskStatus.completed).length;
    final inProgress = tasks.where((t) => t.status == TaskStatus.inProgress);
    final current = inProgress.isEmpty ? null : inProgress.first.text;
    final summary = '${tasks.length} task${tasks.length == 1 ? '' : 's'} · $done done';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: ClideTappable(
        onTap: () => setState(() => _expanded = !_expanded),
        tooltip: _expanded ? 'Collapse tasks' : 'Expand tasks',
        builder: (context, hovered, focused) => Container(
          decoration: BoxDecoration(
            color: (hovered || focused) ? tokens.listItemHoverBackground : tokens.listItemBackground,
            border: Border.all(color: tokens.panelBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The summary row IS the toggle — a single labelled button node
              // (its inner text is announced via the label, so exclude it).
              Semantics(
                button: true,
                label: 'Claude task list, $summary, ${_expanded ? 'expanded' : 'collapsed'}',
                excludeSemantics: true,
                child: _summaryRow(tokens, summary, current),
              ),
              if (_expanded) ...[
                ClideDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final t in tasks) _taskRow(tokens, t)]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(SurfaceTokens tokens, String summary, String? current) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Row(
      children: [
        ClideIcon(_expanded ? const ChevronDownIcon() : const ChevronRightIcon(), size: 12, color: tokens.globalTextMuted),
        const SizedBox(width: 8),
        ClideText(summary, fontSize: clideFontCaption, color: tokens.globalTextMuted),
        if (!_expanded && current != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: ClideText(current, fontSize: clideFontCaption, color: tokens.globalTextMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ] else
          const Spacer(),
      ],
    ),
  );

  Widget _taskRow(SurfaceTokens tokens, TaskItem t) {
    final (String glyph, Color color, String word) = switch (t.status) {
      TaskStatus.completed => ('check-circle', tokens.statusSuccess, 'done'),
      TaskStatus.inProgress => ('circle-half', tokens.globalFocus, 'in progress'),
      TaskStatus.pending => ('circle', tokens.globalTextMuted, 'pending'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        label: '${t.text}, $word',
        container: true,
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: ClideIcon(PhosphorIcons.byName(glyph), size: 13, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClideText(t.text, fontSize: clideFontCaption, color: t.status == TaskStatus.completed ? tokens.globalTextMuted : tokens.globalForeground),
            ),
          ],
        ),
      ),
    );
  }
}
