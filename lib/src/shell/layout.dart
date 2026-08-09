/// The root three-column layout grid, the status bar, and its
/// collapse toggles + bottom icon rails. Split out of app.dart (T-394).
library;

import 'package:clide/builtin/clide_companion/src/companion_state.dart';
import 'package:clide/builtin/clide_companion/src/rail_toggle.dart';
import 'package:clide/extension/src/contribution.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/shell/slot_host.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class RootLayout extends StatelessWidget {
  const RootLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([kernel.panels, kernel.arrangement]),
      builder: (ctx, _) {
        final a = kernel.arrangement;
        final sidebarVisible = a.isVisible(Slots.sidebar);
        final sidebarCollapsed = a.isCollapsed(Slots.sidebar);
        final contextVisible = a.isVisible(Slots.contextPanel);
        final contextCollapsed = a.isCollapsed(Slots.contextPanel);
        final statusVisible = a.isVisible(Slots.statusbar);
        final sidebarSize = a.sizeOf(Slots.sidebar) ?? 400;
        final contextSize = a.sizeOf(Slots.contextPanel) ?? 420;
        final statusHeight = a.sizeOf(Slots.statusbar) ?? 26;
        // Bottom output dock (T-54 / D-87): pushes the workspace up when open,
        // capped at half the window so Claude stays the largest surface (the
        // D-47 amendment).
        final dockVisible = a.isVisible(Slots.dock);
        final dockMax = (((MediaQuery.of(ctx).size.height) - statusHeight) * 0.5).clamp(80.0, double.infinity).toDouble();
        final dockHeight = dockVisible ? ((a.sizeOf(Slots.dock) ?? 200).clamp(0.0, dockMax)).toDouble() : 0.0;

        final column = Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (sidebarVisible && sidebarCollapsed)
                    ClideSpine(label: _sidebarSpineLabel(kernel), side: SpineSide.left, onExpand: () => a.setCollapsed(Slots.sidebar, false))
                  else if (sidebarVisible) ...[
                    SizedBox(
                      width: sidebarSize,
                      child: SlotHost(slot: Slots.sidebar),
                    ),
                    DragResizeHandle(arrangement: a, slot: Slots.sidebar, axis: Axis.horizontal),
                  ],
                  const Expanded(child: SlotHost(slot: Slots.workspace)),
                  if (contextVisible && contextCollapsed)
                    ClideSpine(label: 'context', side: SpineSide.right, onExpand: () => a.setCollapsed(Slots.contextPanel, false))
                  else if (contextVisible) ...[
                    DragResizeHandle(arrangement: a, slot: Slots.contextPanel, axis: Axis.horizontal),
                    SizedBox(
                      width: contextSize,
                      child: SlotHost(slot: Slots.contextPanel),
                    ),
                  ],
                ],
              ),
            ),
            if (dockVisible)
              SizedBox(
                height: dockHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: ClideSettings.theme.of(ctx).surface.chromeBorder)),
                  ),
                  child: SlotHost(slot: Slots.dock),
                ),
              ),
            if (statusVisible)
              Container(
                height: statusHeight,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: ClideSettings.theme.of(ctx).surface.chromeBorder)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Collapse toggles are pinned to the screen edges (outermost
                    // children) so they never shift when a pane collapses (T-294).
                    StatusbarCollapseToggle(slot: Slots.sidebar, collapsed: sidebarCollapsed, visible: sidebarVisible),
                    if (sidebarVisible && !sidebarCollapsed)
                      SizedBox(
                        width: sidebarSize,
                        child: _BottomRail(slot: Slots.sidebar),
                      )
                    else if (sidebarVisible && sidebarCollapsed)
                      const SizedBox(width: ClideSpine.width),
                    const Expanded(child: StatusbarHost()),
                    if (contextVisible && !contextCollapsed)
                      SizedBox(
                        width: contextSize,
                        child: _BottomRail(slot: Slots.contextPanel),
                      )
                    else if (contextVisible && contextCollapsed)
                      const SizedBox(width: ClideSpine.width),
                    StatusbarCollapseToggle(slot: Slots.contextPanel, collapsed: contextCollapsed, visible: contextVisible),
                  ],
                ),
              ),
          ],
        );
        // When the status bar is hidden it no longer occupies the window's
        // bottom edge, so the bottom-most content (the Claude composer, an
        // editor, a terminal) would otherwise run flush into the resize-drag
        // strip and look jammed against the window bottom (T-298). Reserve a
        // matching inset so the interaction zone bottom-anchors consistently,
        // independent of status-bar visibility.
        if (statusVisible) return column;
        return Padding(
          padding: const EdgeInsets.only(bottom: ClideResizeBorder.edgeThickness),
          child: column,
        );
      },
    );
  }

  static String _sidebarSpineLabel(KernelServices kernel) {
    final activeTab = kernel.panels.activeTabIn(Slots.sidebar);
    if (activeTab == null) return 'overview';
    final tabs = kernel.panels.tabsFor(Slots.sidebar);
    for (final t in tabs) {
      if (t.id == activeTab) return t.title.toLowerCase();
    }
    return 'overview';
  }
}

class _BottomRail extends StatelessWidget {
  const _BottomRail({required this.slot});
  final SlotId slot;

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideSettings.theme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.panels,
      builder: (ctx, _) {
        final tabs = kernel.panels.tabsFor(slot);
        if (tabs.isEmpty) return Container(color: tokens.chromeBackground);
        final activeId = kernel.panels.activeTabIn(slot) ?? tabs.first.id;
        final items = [for (final t in tabs) ClideIconRailItem(id: t.id, icon: _iconFor(slot, t), tooltip: resolveTabTitle(ctx, t), iconColor: t.iconColor)];

        Widget rail(List<ClideIconRailToggle> toggles) => Container(
          color: tokens.chromeBackground,
          child: ClideIconRail(items: items, activeId: activeId, onSelect: (id) => kernel.panels.activateTab(slot, id), toggles: toggles),
        );

        // Only the context panel's rail carries it — that is the column the
        // strip shares, so that is where the control for it belongs (T-528).
        if (slot != Slots.contextPanel) return rail(const []);
        return CompanionStateBuilder(builder: (ctx, state) => rail([?companionRailToggle(ctx, state)]));
      },
    );
  }

  static ClideIconPainter _iconFor(SlotId slot, TabContribution t) {
    if (t.icon is ClideIconPainter) return t.icon as ClideIconPainter;
    if (slot == Slots.sidebar) {
      return switch (t.id) {
        'files.tree' => PhosphorIcons.byName('folder'),
        'git.panel' => PhosphorIcons.byName('git-branch'),
        'pql.panel' => PhosphorIcons.byName('magnifying-glass'),
        'problems.panel' => PhosphorIcons.byName('warning-circle'),
        'decisions.panel' => PhosphorIcons.byName('lightbulb'),
        'tickets.panel' => PhosphorIcons.byName('ticket'),
        _ => PhosphorIcons.byName('circles-four'),
      };
    }
    return switch (t.id) {
      'markdown.viewer' => PhosphorIcons.byName('eye'),
      'graph.view' => PhosphorIcons.byName('graph'),
      'pql.backlinks' => PhosphorIcons.byName('link'),
      _ => PhosphorIcons.byName('circles-four'),
    };
  }
}

/// A fixed-position collapse/expand toggle bookending the status bar (T-294).
/// The left cell controls the sidebar, the right cell the context pane; both
/// fire the existing `sidebar.collapse` / `context.collapse` commands and flip a
/// caret-line chevron per `arrangement.isCollapsed` (outward = expand, inward =
/// collapse). The collapse behaviour itself lives in the commands (D-51/D-54);
/// this is the mouse affordance for the keyboard/CLI-addressable action (D-6).
/// A fixed collapse/expand toggle pinned to a screen edge of the status bar
/// (T-294). Lives at the outer ends of the bar — NOT inside the centre
/// [StatusbarHost] — so it never shifts when a pane collapses and the centre
/// bar resizes. [collapsed]/[visible] are passed in (not read from the
/// arrangement here) so the widget varies with state and rebuilds when its
/// parent's `ListenableBuilder` fires — a const widget reading the arrangement
/// itself is skipped as identical on rebuild, freezing the chevron.
class StatusbarCollapseToggle extends StatelessWidget {
  const StatusbarCollapseToggle({super.key, required this.slot, required this.collapsed, required this.visible});

  final SlotId slot;
  final bool collapsed;
  final bool visible;

  bool get _isSidebar => slot == Slots.sidebar;

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideSettings.theme.of(context).surface;
    if (!visible) return const SizedBox(width: 24);
    // The chevron points the DIRECTION OF THE ACTION: collapsing tucks the pane
    // toward its own edge, expanding brings it back toward the centre.
    final icon = _isSidebar
        ? (collapsed ? PhosphorIcons.byName('caret-line-right') : PhosphorIcons.byName('caret-line-left'))
        : (collapsed ? PhosphorIcons.byName('caret-line-left') : PhosphorIcons.byName('caret-line-right'));
    final what = _isSidebar ? 'sidebar' : 'context panel';
    return SizedBox(
      width: 24,
      child: ClideTappable(
        onTap: () => kernel.commands.execute(_isSidebar ? 'sidebar.collapse' : 'context.collapse'),
        tooltip: collapsed ? 'Show $what' : 'Hide $what',
        builder: (ctx, hovered, focused) => Container(
          alignment: Alignment.center,
          color: (hovered || focused) ? tokens.listItemHoverBackground : null,
          child: ClideIcon(icon, size: 13, color: tokens.statusBarForeground),
        ),
      ),
    );
  }
}

class StatusbarHost extends StatelessWidget {
  const StatusbarHost({super.key});

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideSettings.theme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.panels,
      builder: (ctx, _) {
        final items = kernel.panels.contributionsFor(Slots.statusbar).whereType<StatusItemContribution>().toList();
        final left = items.where((i) => i.priority < 100).toList();
        final right = items.where((i) => i.priority >= 100).toList();
        // Two explicit columns within the center (workspace) bar: the LEFT
        // group lives in an Expanded so it absorbs all free space and is
        // start-aligned, and the RIGHT group (tool status, theme switcher)
        // trails it at intrinsic width — so it hugs the workspace block's
        // right edge by construction, no Spacer to fight a flex item (T-239).
        // Left items with flex > 0 wrap in Flexible(loose) so they yield width
        // when tight (T-160).
        return Container(
          color: tokens.chromeBackground,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (final item in left)
                      if (item.flex > 0) Flexible(flex: item.flex, fit: FlexFit.loose, child: item.build(ctx)) else item.build(ctx),
                  ],
                ),
              ),
              for (final item in right) item.build(ctx),
            ],
          ),
        );
      },
    );
  }
}
