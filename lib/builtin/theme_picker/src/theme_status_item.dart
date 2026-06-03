/// Status-bar theme switcher (T-234). A compact right-aligned control
/// showing the current theme; activating it opens a popover (anchored
/// above the status bar, not a full-screen modal) listing every theme,
/// with live-apply on select. The modal `theme.pick` command is unchanged
/// (D-6 parity — both reach the same ThemeController).
library;

import 'package:clide/builtin/theme_picker/src/theme_families.dart';
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
                onClose: _close,
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
                  ClideIcon(PhosphorIcons.palette, size: 13, color: tokens.statusBarForeground),
                  const SizedBox(width: 6),
                  // The status bar is all-lowercase; the proper-case name stays
                  // in the Semantics label for screen readers.
                  ClideText(label.toLowerCase(), fontSize: clideFontCaption, color: tokens.statusBarForeground),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The popover body: a "High contrast" toggle then the base themes (the `-hc`
/// siblings collapse into the toggle, T-237). Keyboard-navigable as one list —
/// index 0 is the toggle, 1..N the themes; arrows move, Enter activates, Esc
/// dismisses. Autofocuses on open.
class _ThemePopover extends StatefulWidget {
  const _ThemePopover({required this.controller, required this.onClose});

  final ThemeController controller;
  final VoidCallback onClose;

  @override
  State<_ThemePopover> createState() => _ThemePopoverState();
}

class _ThemePopoverState extends State<_ThemePopover> {
  final _focus = FocusNode(debugLabel: 'ThemeSwitcher.popover');
  late bool _hc;
  int _index = 0;

  List<ThemeDefinition> get _themes => baseThemes(widget.controller.available);

  @override
  void initState() {
    super.initState();
    _hc = isHcName(widget.controller.currentName);
    final currentBase = baseThemeName(widget.controller.currentName);
    final at = _themes.indexWhere((t) => t.name == currentBase);
    _index = at < 0 ? 0 : at + 1; // +1: row 0 is the toggle
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _toggleHc() {
    setState(() => _hc = !_hc);
    // Re-apply the current base with the new variant, live; keep the popover open.
    final base = baseThemeName(widget.controller.currentName);
    widget.controller.select(resolveThemeName(widget.controller.available, base, highContrast: _hc));
  }

  void _pick(ThemeDefinition base) {
    widget.controller.select(resolveThemeName(widget.controller.available, base.name, highContrast: _hc));
    widget.onClose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final count = _themes.length + 1; // +1 toggle
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _index = (_index + 1) % count);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        setState(() => _index = (_index - 1 + count) % count);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (_index == 0) {
          _toggleHc();
        } else {
          _pick(_themes[_index - 1]);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onClose();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final themes = _themes;
    final currentBase = baseThemeName(widget.controller.currentName);
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Semantics(
        container: true,
        label: 'Theme switcher',
        explicitChildNodes: true,
        child: ClideSurface(
          width: 280,
          color: tokens.modalSurfaceBackground,
          border: tokens.modalSurfaceBorder,
          padding: const EdgeInsets.all(4),
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HighContrastToggle(
                    checked: _hc,
                    highlighted: _index == 0,
                    onEnter: () => setState(() => _index = 0),
                    onTap: _toggleHc,
                  ),
                  ClideDivider(),
                  for (var i = 0; i < themes.length; i++)
                    _PopoverRow(
                      displayName: themes[i].displayName,
                      selected: themes[i].name == currentBase,
                      highlighted: _index == i + 1,
                      onEnter: () => setState(() => _index = i + 1),
                      onTap: () => _pick(themes[i]),
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

/// The "High contrast" checkbox row at the top of the popover.
class _HighContrastToggle extends StatelessWidget {
  const _HighContrastToggle({required this.checked, required this.highlighted, required this.onEnter, required this.onTap});

  final bool checked;
  final bool highlighted;
  final VoidCallback onEnter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      checked: checked,
      label: 'High contrast',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onEnter(),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            color: highlighted ? tokens.listItemHoverBackground : tokens.listItemBackground,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: checked ? tokens.buttonBackground : null,
                    border: Border.all(color: checked ? tokens.buttonBackground : tokens.modalSurfaceBorder),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: checked ? ClideIcon(const CheckIcon(), size: 9, color: tokens.buttonForeground) : null,
                ),
                const SizedBox(width: 8),
                Expanded(child: ClideText('High contrast', color: tokens.listItemForeground, fontSize: clideFontCaption)),
              ],
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
                Expanded(child: ClideText(displayName, color: fg, fontSize: clideFontCaption, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
