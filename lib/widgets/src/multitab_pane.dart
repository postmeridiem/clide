import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:clide/widgets/src/clide_text.dart';
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
    this.tabHeight = 28,
  });

  final MultitabController<T> controller;
  final MultitabBuilder<T> bodyBuilder;
  final MultitabEntryCallback<T>? onCloseRequested;
  final VoidCallback? onAddRequested;
  final bool allowReorder;
  final double tabHeight;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final active = controller.active;
        return Column(
          children: [
            _TabStrip<T>(
              controller: controller,
              onCloseRequested: onCloseRequested,
              onAddRequested: onAddRequested,
              allowReorder: allowReorder,
              tabHeight: tabHeight,
            ),
            Expanded(
              child: active == null
                  ? const SizedBox.expand()
                  : KeyedSubtree(
                      // Key by id so swapping the active tab rebuilds
                      // body state cleanly instead of mutating in place.
                      key: ValueKey('multitab-body-${active.id}'),
                      child: bodyBuilder(context, active),
                    ),
            ),
          ],
        );
      },
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
      color: tokens.tabBarBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in entries)
              _Tab<T>(
                entry: entry,
                active: entry.id == activeId,
                onSelect: () => controller.activate(entry.id),
                onClose: entry.closeable
                    ? () {
                        if (onCloseRequested != null) {
                          onCloseRequested!(entry);
                        } else {
                          controller.remove(entry.id);
                        }
                      }
                    : null,
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                top: BorderSide(color: border, width: widget.active ? 1.5 : 0),
                left: BorderSide(color: tokens.panelBorder),
                right: BorderSide(color: tokens.panelBorder),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ClideText(
                    widget.entry.title,
                    fontSize: 12,
                    color: fg,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
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
                        child: ClideText('×',
                            fontSize: 14, color: tokens.globalTextMuted),
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

