import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/icons/x.dart';
import 'package:clide/widgets/src/multitab_controller.dart';
import 'package:flutter/widgets.dart';

typedef MultitabBuilder<T> = Widget Function(BuildContext context, MultitabEntry<T> entry);
typedef MultitabEntryCallback<T> = void Function(MultitabEntry<T> entry);

/// A pane shell that hosts N runtime tabs of the same kind. Routes
/// the user's add / close / reorder / activate gestures back to the
/// host via the [controller] and the optional callbacks.
///
/// The widget is generic and domain-free: it never knows what's
/// inside a tab. Hosts pick `T` and decide what add / close mean
/// (e.g. spawning or killing a tmux session for the Claude pane).
///
/// See `docs/design/multitab-pane.md` for the design rationale.
class MultitabPane<T> extends StatelessWidget {
  const MultitabPane({
    super.key,
    required this.controller,
    required this.bodyBuilder,
    this.onCloseRequested,
    this.onAddRequested,
    this.allowReorder = true,
    this.keepAlive = false,
    this.tabHeight = 28,
  });

  final MultitabController<T> controller;
  final MultitabBuilder<T> bodyBuilder;
  final MultitabEntryCallback<T>? onCloseRequested;
  final VoidCallback? onAddRequested;
  final bool allowReorder;

  /// When true, all entry bodies stay mounted across tab switches
  /// (via [IndexedStack]). Use this for tabs that own long-lived
  /// state — PTY-backed sessions, editor buffers, anything where
  /// rebuilding from scratch on every switch loses state. Default
  /// is false: only the active body builds, switching disposes the
  /// old body and rebuilds the new one.
  final bool keepAlive;

  final double tabHeight;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final entries = controller.entries;
        final active = controller.active;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TabStrip<T>(
              controller: controller,
              onCloseRequested: onCloseRequested,
              onAddRequested: onAddRequested,
              allowReorder: allowReorder,
              tabHeight: tabHeight,
            ),
            Expanded(child: _body(context, entries, active)),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, List<MultitabEntry<T>> entries, MultitabEntry<T>? active) {
    if (active == null || entries.isEmpty) return const SizedBox.expand();
    if (!keepAlive) {
      // Single-body mode: rebuild on every active change. Key by id
      // so a stable body widget tree gets a fresh State on switch.
      return KeyedSubtree(
        key: ValueKey('multitab-body-${active.id}'),
        child: bodyBuilder(context, active),
      );
    }
    // Keep-alive mode: every body stays mounted; switching is just
    // an IndexedStack index change. Bodies preserve their State.
    final activeIndex = entries.indexWhere((e) => e.id == active.id);
    return IndexedStack(
      index: activeIndex < 0 ? 0 : activeIndex,
      children: [
        for (final entry in entries)
          KeyedSubtree(
            key: ValueKey('multitab-body-${entry.id}'),
            child: bodyBuilder(context, entry),
          ),
      ],
    );
  }
}

class _TabStrip<T> extends StatelessWidget {
  const _TabStrip({
    required this.controller,
    required this.onCloseRequested,
    required this.onAddRequested,
    required this.allowReorder,
    required this.tabHeight,
  });

  final MultitabController<T> controller;
  final MultitabEntryCallback<T>? onCloseRequested;
  final VoidCallback? onAddRequested;
  final bool allowReorder;
  final double tabHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final entries = controller.entries;
    final activeId = controller.activeId;

    return Container(
      height: tabHeight,
      decoration: BoxDecoration(
        color: tokens.tabBarBackground,
        border: Border(bottom: BorderSide(color: tokens.dividerColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < entries.length; i++)
              _ReorderableTab<T>(
                entry: entries[i],
                index: i,
                active: entries[i].id == activeId,
                allowReorder: allowReorder,
                onSelect: () => controller.activate(entries[i].id),
                onClose: entries[i].closeable
                    ? () {
                        if (onCloseRequested != null) {
                          onCloseRequested!(entries[i]);
                        } else {
                          controller.remove(entries[i].id);
                        }
                      }
                    : null,
                onReorderTo: (draggedId) =>
                    controller.reorder(draggedId, i),
                tabHeight: tabHeight,
              ),
            if (onAddRequested != null)
              _AddButton(onTap: onAddRequested!, tabHeight: tabHeight),
          ],
        ),
      ),
    );
  }
}

/// Wraps a [_Tab] with [Draggable] (when [allowReorder] is true and the
/// entry itself permits reorder) and [DragTarget] (always — the
/// controller's barrier logic decides whether a drop actually moves
/// the tab). Drop target inserts the dragged id at this tab's index.
class _ReorderableTab<T> extends StatefulWidget {
  const _ReorderableTab({
    required this.entry,
    required this.index,
    required this.active,
    required this.allowReorder,
    required this.onSelect,
    required this.onClose,
    required this.onReorderTo,
    required this.tabHeight,
  });

  final MultitabEntry<T> entry;
  final int index;
  final bool active;
  final bool allowReorder;
  final VoidCallback onSelect;
  final VoidCallback? onClose;
  final void Function(String draggedId) onReorderTo;
  final double tabHeight;

  @override
  State<_ReorderableTab<T>> createState() => _ReorderableTabState<T>();
}

class _ReorderableTabState<T> extends State<_ReorderableTab<T>> {
  bool _isDropTarget = false;

  bool get _draggable => widget.allowReorder && widget.entry.reorderable;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;

    final tabContent = _Tab<T>(
      entry: widget.entry,
      active: widget.active,
      onSelect: widget.onSelect,
      onClose: widget.onClose,
      tabHeight: widget.tabHeight,
    );

    Widget result = DragTarget<String>(
      onWillAcceptWithDetails: (d) {
        if (d.data == widget.entry.id) return false;
        return widget.allowReorder;
      },
      onMove: (_) {
        if (!_isDropTarget) setState(() => _isDropTarget = true);
      },
      onLeave: (_) {
        if (_isDropTarget) setState(() => _isDropTarget = false);
      },
      onAcceptWithDetails: (d) {
        setState(() => _isDropTarget = false);
        widget.onReorderTo(d.data);
      },
      builder: (context, _, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 2,
            height: widget.tabHeight,
            child: ColoredBox(
              color: _isDropTarget ? tokens.panelActiveBorder : const Color(0x00000000),
            ),
          ),
          tabContent,
        ],
      ),
    );

    if (_draggable) {
      result = Draggable<String>(
        data: widget.entry.id,
        axis: Axis.horizontal,
        feedback: _DragFeedback(
          title: widget.entry.title,
          tabHeight: widget.tabHeight,
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: tabContent),
        child: result,
      );
    }

    return result;
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.title, required this.tabHeight});
  final String title;
  final double tabHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      height: tabHeight,
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: tokens.panelHeader,
        border: Border.all(color: tokens.panelActiveBorder),
      ),
      child: ClideText(
        title,
        fontSize: 12,
        color: tokens.tabActiveForeground,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

class _Tab<T> extends StatefulWidget {
  const _Tab({
    required this.entry,
    required this.active,
    required this.onSelect,
    required this.onClose,
    required this.tabHeight,
  });

  final MultitabEntry<T> entry;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback? onClose;
  final double tabHeight;

  @override
  State<_Tab<T>> createState() => _TabState<T>();
}

class _TabState<T> extends State<_Tab<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final fg = widget.active ? tokens.tabActiveForeground : tokens.tabInactiveForeground;
    // Active tabs sit on the elevated chrome surface (panelHeader);
    // inactive tabs blend into the tab bar.
    final bg = widget.active ? tokens.panelHeader : tokens.tabBarBackground;
    final border = widget.active ? tokens.panelActiveBorder : tokens.panelBorder;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        selected: widget.active,
        label: widget.entry.title,
        excludeSemantics: true,
        child: ClideTappable(
          onTap: widget.onSelect,
          builder: (context, _, __) => Container(
            constraints: BoxConstraints(minWidth: 96, maxWidth: 200),
            height: widget.tabHeight,
            // Left margin stays at 12 (text breathing room).
            // Right margin matches the close button's vertical
            // breathing room ((tabHeight − iconSize) / 2 ≈ 6) so the
            // gap around the icon is uniform on top, bottom, and right.
            padding: EdgeInsets.only(
              left: 12,
              right: widget.onClose != null ? 6 : 12,
            ),
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                top: BorderSide(color: border, width: widget.active ? 1.5 : 0),
                left: BorderSide(color: tokens.panelBorder),
                right: BorderSide(color: tokens.panelBorder),
              ),
            ),
            child: Row(
              children: [
                // Left column: title, takes all remaining space.
                Expanded(
                  child: ClideText(
                    widget.entry.title,
                    fontSize: 12,
                    color: fg,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                // Right column: close icon, fixed natural width.
                if (widget.onClose != null) ...[
                  const SizedBox(width: 8),
                  Opacity(
                    opacity: _hovered || widget.active ? 1.0 : 0.0,
                    child: ClideTappable(
                      onTap: widget.onClose,
                      builder: (context, hovered, _) => Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hovered ? tokens.listItemHoverBackground : null,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: ClideIcon(
                          const CloseIcon(),
                          size: 10,
                          color: hovered ? tokens.globalForeground : tokens.globalTextMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, required this.tabHeight});
  final VoidCallback onTap;
  final double tabHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      button: true,
      label: 'New tab',
      excludeSemantics: true,
      child: ClideTappable(
        onTap: onTap,
        builder: (context, hovered, _) => Container(
          width: 28,
          height: tabHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered ? tokens.listItemHoverBackground : null,
          ),
          child: ClideText('+',
              fontSize: 14,
              color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
        ),
      ),
    );
  }
}

