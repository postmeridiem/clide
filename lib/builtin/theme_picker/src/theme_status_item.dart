/// Status-bar theme switcher (T-234). A compact right-aligned control
/// showing the current theme; activating it opens a popover (anchored
/// above the status bar, not a full-screen modal) listing every theme,
/// with live-apply on select. The modal `theme.pick` command is unchanged
/// (D-6 parity — both reach the same ThemeController).
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;

class ThemeSwitcherStatusItem extends StatefulWidget {
  const ThemeSwitcherStatusItem({super.key});

  static const ns = 'builtin.theme-picker';

  @override
  State<ThemeSwitcherStatusItem> createState() => _ThemeSwitcherStatusItemState();
}

class _ThemeSwitcherStatusItemState extends State<ThemeSwitcherStatusItem> {
  OverlayEntry? _entry;
  bool get _open => _entry != null;

  ThemeController get _controller => ClideKernel.of(context).theme;

  void _toggle() => _open ? _close() : _openPopover();

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  void _openPopover() {
    final overlay = Overlay.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null) return;
    final anchor = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screen = MediaQuery.of(context).size;

    _entry = OverlayEntry(
      builder: (ctx) {
        // Anchor the popover's bottom-right to the control's top-right so it
        // grows upward (the status bar lives at the window bottom).
        final right = (screen.width - (anchor.dx + size.width)).clamp(0.0, screen.width);
        return Stack(
          children: [
            // Tap-away barrier — dismisses without changing the theme.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
            Positioned(
              right: right,
              bottom: screen.height - anchor.dy + 4,
              child: _ThemePopover(
                controller: _controller,
                onPick: (name) {
                  _controller.select(name);
                  _close();
                },
                onDismiss: _close,
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_entry!);
    setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final label = _controller.current.displayName;
        return Semantics(
          button: true,
          expanded: _open,
          label: 'Theme: $label',
          hint: 'Open the theme switcher',
          excludeSemantics: true,
          child: ClideTappable(
            onTap: _toggle,
            builder: (context, hovered, focused) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: (hovered || focused || _open) ? tokens.listItemHoverBackground : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A swatch dot in the theme's accent — the "what theme" cue.
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: tokens.buttonBackground, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  ClideText(label, fontSize: clideFontCaption, color: tokens.statusBarForeground),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The popover body: a keyboard-navigable list of themes. Autofocuses so
/// arrows/Enter/Esc work immediately; the current theme starts highlighted.
class _ThemePopover extends StatefulWidget {
  const _ThemePopover({required this.controller, required this.onPick, required this.onDismiss});

  final ThemeController controller;
  final void Function(String name) onPick;
  final VoidCallback onDismiss;

  @override
  State<_ThemePopover> createState() => _ThemePopoverState();
}

class _ThemePopoverState extends State<_ThemePopover> {
  final _focus = FocusNode(debugLabel: 'ThemeSwitcher.popover');
  late int _index;

  @override
  void initState() {
    super.initState();
    final themes = widget.controller.available;
    _index = themes.indexWhere((t) => t.name == widget.controller.currentName);
    if (_index < 0) _index = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final themes = widget.controller.available;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _index = (_index + 1) % themes.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        setState(() => _index = (_index - 1 + themes.length) % themes.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        widget.onPick(themes[_index].name);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onDismiss();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final themes = widget.controller.available;
    final currentName = widget.controller.currentName;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Semantics(
        container: true,
        label: 'Theme switcher',
        explicitChildNodes: true,
        child: ClideSurface(
          width: 240,
          color: tokens.modalSurfaceBackground,
          border: tokens.modalSurfaceBorder,
          padding: const EdgeInsets.all(4),
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < themes.length; i++)
                    _PopoverRow(
                      displayName: themes[i].displayName,
                      selected: themes[i].name == currentName,
                      highlighted: i == _index,
                      onEnter: () => setState(() => _index = i),
                      onTap: () => widget.onPick(themes[i].name),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopoverRow extends StatelessWidget {
  const _PopoverRow({
    required this.displayName,
    required this.selected,
    required this.highlighted,
    required this.onEnter,
    required this.onTap,
  });

  final String displayName;
  final bool selected;
  final bool highlighted;
  final VoidCallback onEnter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final bg = selected ? tokens.listItemSelectedBackground : (highlighted ? tokens.listItemHoverBackground : tokens.listItemBackground);
    final fg = selected ? tokens.listItemSelectedForeground : tokens.listItemForeground;
    return Semantics(
      button: true,
      selected: selected,
      label: displayName,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onEnter(),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            color: bg,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ClideIcon(const CheckIcon(), size: 11, color: fg),
                  )
                else
                  const SizedBox(width: 17),
                Expanded(child: ClideText(displayName, color: fg, fontSize: clideFontCaption)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
