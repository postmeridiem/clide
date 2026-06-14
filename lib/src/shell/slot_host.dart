/// Slot hosting: mounts a slot's tab contributions, integrates focus
/// scopes, and renders the slot-specific bodies (sidebar / workspace
/// split incl. the editor drag handle / context). Split out of
/// app.dart (T-394).
library;

import 'package:clide/extension/src/contribution.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class SlotHost extends StatefulWidget {
  const SlotHost({super.key, required this.slot});
  final SlotId slot;

  @override
  State<SlotHost> createState() => _SlotHostState();
}

class _SlotHostState extends State<SlotHost> {
  late final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'SlotScope:${widget.slot.value}');
  FocusTracker? _tracker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final kernel = ClideKernel.of(context);
    if (!identical(_tracker, kernel.focus)) {
      _tracker?.unregisterSlotScope(widget.slot, _scope);
      _tracker = kernel.focus;
      _tracker!.registerSlotScope(widget.slot, _scope);
    }
  }

  @override
  void dispose() {
    _tracker?.unregisterSlotScope(widget.slot, _scope);
    _scope.dispose();
    super.dispose();
  }

  void _onFocusChange(bool hasFocus) {
    if (!hasFocus || _tracker == null) return;
    final kernel = ClideKernel.of(context);
    final activeId = kernel.panels.activeTabIn(widget.slot);
    if (activeId != null) {
      _tracker!.setActive(slot: widget.slot, contributionId: activeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return FocusScope(
      node: _scope,
      onFocusChange: _onFocusChange,
      child: FocusTraversalGroup(
        child: ListenableBuilder(
          listenable: Listenable.merge([kernel.panels, kernel.i18n]),
          builder: (ctx, _) {
            final tabs = kernel.panels.tabsFor(widget.slot);
            if (tabs.isEmpty) {
              return Container(color: tokens.panelBackground);
            }
            final activeId = kernel.panels.activeTabIn(widget.slot) ?? tabs.first.id;
            final active = tabs.firstWhere((t) => t.id == activeId, orElse: () => tabs.first);
            return _SlotBody(slot: widget.slot, tabs: tabs, active: active, activeId: activeId);
          },
        ),
      ),
    );
  }
}

class _SlotBody extends StatelessWidget {
  const _SlotBody({required this.slot, required this.tabs, required this.active, required this.activeId});
  final SlotId slot;
  final List<TabContribution> tabs;
  final TabContribution active;
  final String activeId;

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;

    if (slot == Slots.sidebar) {
      return _SidebarSlot(tabs: tabs, active: active, activeId: activeId, onSelect: (id) => kernel.panels.activateTab(slot, id));
    }

    if (slot == Slots.contextPanel) {
      return _ContextSlot(tabs: tabs, active: active, activeId: activeId, onSelect: (id) => kernel.panels.activateTab(slot, id));
    }

    if (slot == Slots.workspace) {
      return _WorkspaceSlot(tabs: tabs, active: active);
    }

    return Container(
      color: tokens.panelBackground,
      child: Column(
        children: [
          ClideTabBar(
            items: [for (final t in tabs) ClideTabItem(id: t.id, title: resolveTabTitle(context, t))],
            activeId: active.id,
            onSelect: (id) => kernel.panels.activateTab(slot, id),
          ),
          ClideDivider(),
          Expanded(child: active.build(context)),
        ],
      ),
    );
  }
}

class _SidebarSlot extends StatelessWidget {
  const _SidebarSlot({required this.tabs, required this.active, required this.activeId, required this.onSelect});

  final List<TabContribution> tabs;
  final TabContribution active;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      color: tokens.chromeBackground,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.fromLTRB(2, 2, 0, 0),
      child: active.build(context),
    );
  }
}

// Stable identity for the workspace's primary pane (Claude). Opening the
// editor reparents it from a direct child into a Column/Expanded; without a
// stable key Flutter disposes + rebuilds the subtree, and the Claude
// conversation's SelectableRegion then runs a pending selection update
// against now-inactive elements ("selectable not in this registrar" /
// "renderObject of inactive element"). The GlobalKey makes Flutter MOVE the
// element instead, preserving the selection subtree.
final GlobalKey _kWorkspacePrimary = GlobalKey(debugLabel: 'workspace.primary');

class _WorkspaceSlot extends StatelessWidget {
  const _WorkspaceSlot({required this.tabs, required this.active});

  final List<TabContribution> tabs;
  final TabContribution active;

  static const _editorTabId = 'editor.active';
  static const _claudeTabId = 'claude.primary';

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: kernel.arrangement,
      builder: (ctx, _) {
        final editorOpen = kernel.arrangement.editorOpen;
        final editorTab = tabs.where((t) => t.id == _editorTabId).firstOrNull;

        final claude = tabs.where((t) => t.id == _claudeTabId).firstOrNull;
        final primaryPane = KeyedSubtree(key: _kWorkspacePrimary, child: (claude ?? active).build(ctx));

        // A non-Claude, non-editor workspace tab being the active one (e.g.
        // diff.view revealed by `clide ui open diff`, T-233) shows in the split
        // region above Claude — "review alongside the conversation" — with a
        // close affordance back to full-Claude. Only when Claude exists below
        // it; with no Claude pane the active tab just takes the whole slot, as
        // before. The editor keeps its own editorOpen-gated split.
        final reveal = (claude != null && active.id != _claudeTabId && active.id != _editorTabId) ? active : null;
        final topTab = reveal ?? (editorOpen ? editorTab : null);

        if (topTab == null) {
          return Container(color: tokens.panelBackground, child: primaryPane);
        }

        final ratio = kernel.arrangement.editorRatio;
        return Container(
          color: tokens.panelBackground,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final totalHeight = constraints.maxHeight;
              final topHeight = (totalHeight * ratio).clamp(60.0, totalHeight - 60.0);
              return Column(
                children: [
                  SizedBox(
                    height: topHeight,
                    child: reveal != null
                        ? _RevealedTab(tab: reveal, onClose: () => kernel.panels.activateTab(Slots.workspace, _claudeTabId))
                        : topTab.build(ctx),
                  ),
                  _EditorDragHandle(arrangement: kernel.arrangement, totalHeight: totalHeight),
                  Expanded(child: primaryPane),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// A non-Claude workspace tab revealed in the split region above Claude
/// (T-233): a thin chrome header (title + close) over the tab's body, so the
/// user can review it alongside the conversation and dismiss it back to
/// full-Claude. The editor uses its own split path and never renders here.
class _RevealedTab extends StatelessWidget {
  const _RevealedTab({required this.tab, required this.onClose});

  final TabContribution tab;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Column(
      children: [
        Container(
          height: 28,
          padding: const EdgeInsets.only(left: 10, right: 4),
          color: tokens.panelHeader,
          child: Row(
            children: [
              Expanded(
                child: ClideText(resolveTabTitle(context, tab), fontSize: clideFontCaption, color: tokens.panelHeaderForeground, maxLines: 1),
              ),
              Semantics(
                button: true,
                label: 'Close',
                excludeSemantics: true,
                onTap: onClose,
                child: ClideTappable(
                  onTap: onClose,
                  tooltip: 'Close',
                  builder: (_, hovered, _) => Padding(
                    padding: const EdgeInsets.all(6),
                    child: ClideIcon(PhosphorIcons.byName('x'), size: 12, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: tab.build(context)),
      ],
    );
  }
}

class _EditorDragHandle extends StatefulWidget {
  const _EditorDragHandle({required this.arrangement, required this.totalHeight});

  final LayoutArrangement arrangement;
  final double totalHeight;

  @override
  State<_EditorDragHandle> createState() => _EditorDragHandleState();
}

class _EditorDragHandleState extends State<_EditorDragHandle> {
  bool _hovered = false;
  bool _focused = false;
  double? _dragStartRatio;
  double? _dragStartY;

  // Editor split is a 0..1 fraction; the kernel clamps to 0.15..0.70.
  // 2% per fine step, 10% per Shift step keeps keyboard feel close to
  // the pixel-based DragResizeHandle.
  static const double _stepFine = 0.02;
  static const double _stepCoarse = 0.10;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final lineColor = (_hovered || _focused) ? tokens.panelActiveBorder : tokens.panelBorder;

    final ratio = widget.arrangement.editorRatio;
    String pct(double r) => '${(r.clamp(0.15, 0.70) * 100).round()}%';
    return Semantics(
      container: true,
      slider: true,
      label: 'Editor split',
      value: pct(ratio),
      // increase/decrease actions require matching increased/decreased
      // values, or Flutter asserts on every semantics flush.
      increasedValue: pct(ratio + _stepFine),
      decreasedValue: pct(ratio - _stepFine),
      onIncrease: () => _bump(_stepFine),
      onDecrease: () => _bump(-_stepFine),
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowUp): _EditorBumpIntent(-_stepFine),
          SingleActivator(LogicalKeyboardKey.arrowDown): _EditorBumpIntent(_stepFine),
          SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): _EditorBumpIntent(-_stepCoarse),
          SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): _EditorBumpIntent(_stepCoarse),
        },
        actions: <Type, Action<Intent>>{
          _EditorBumpIntent: CallbackAction<_EditorBumpIntent>(
            onInvoke: (intent) {
              _bump(intent.delta);
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeRow,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            onPointerDown: (e) {
              _dragStartRatio = widget.arrangement.editorRatio;
              _dragStartY = e.position.dy;
            },
            onPointerMove: (e) {
              final startR = _dragStartRatio;
              final startY = _dragStartY;
              if (startR == null || startY == null || widget.totalHeight <= 0) return;
              final deltaRatio = (e.position.dy - startY) / widget.totalHeight;
              widget.arrangement.setEditorRatio(startR + deltaRatio);
            },
            onPointerUp: (_) {
              _dragStartRatio = null;
              _dragStartY = null;
            },
            child: Container(height: 4, color: lineColor),
          ),
        ),
      ),
    );
  }

  void _bump(double delta) {
    widget.arrangement.setEditorRatio(widget.arrangement.editorRatio + delta);
  }
}

class _EditorBumpIntent extends Intent {
  const _EditorBumpIntent(this.delta);
  final double delta;
}

class _ContextSlot extends StatelessWidget {
  const _ContextSlot({required this.tabs, required this.active, required this.activeId, required this.onSelect});

  final List<TabContribution> tabs;
  final TabContribution active;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(color: tokens.panelBackground, alignment: Alignment.topLeft, padding: const EdgeInsets.only(right: 2), child: active.build(context));
  }
}

/// Resolve a tab's display title through i18n when it carries a key +
/// namespace, else its static title. Shared by the slot bodies, the
/// revealed-tab header, and the bottom icon rails.
String resolveTabTitle(BuildContext context, TabContribution t) {
  final key = t.titleKey;
  final ns = t.i18nNamespace;
  if (key == null || ns == null) return t.title;
  return ClideKernel.of(context).i18n.string(key, namespace: ns, placeholder: t.title);
}
