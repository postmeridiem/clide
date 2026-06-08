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

class ThemeSwitcherStatusItem extends StatefulWidget {
  const ThemeSwitcherStatusItem({super.key});

  static const ns = 'builtin.theme-picker';

  @override
  State<ThemeSwitcherStatusItem> createState() => _ThemeSwitcherStatusItemState();
}

class _ThemeSwitcherStatusItemState extends State<ThemeSwitcherStatusItem> {
  final ClideOverlayController _overlay = ClideOverlayController();

  ThemeController get _controller => ClideKernel.of(context).theme;

  @override
  void dispose() {
    _overlay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    // Listen to both the theme (label changes) and the overlay (open state).
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _overlay]),
      builder: (context, _) {
        final label = _controller.current.displayName;
        final open = _overlay.isOpen;
        return ClideAnchoredOverlay(
          controller: _overlay,
          // The status bar lives at the window bottom, so the popover opens
          // upward, right-aligned to the control; autoFlip handles the rare
          // case where it sits high enough to grow down (e.g. in tests).
          side: ClideAnchorSide.above,
          align: ClideAnchorAlign.end,
          offset: const Offset(0, -4),
          anchor: Semantics(
            button: true,
            expanded: open,
            label: 'Theme: $label',
            hint: 'Open the theme switcher',
            excludeSemantics: true,
            child: ClideTappable(
              onTap: _overlay.toggle,
              builder: (context, hovered, focused) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                color: (hovered || focused || open) ? tokens.listItemHoverBackground : null,
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
          ),
          overlayBuilder: (ctx, ctrl) => _ThemePopover(controller: _controller, onClose: ctrl.close),
        );
      },
    );
  }
}

/// The popover body, rendered on the shared [ClideMenu] (D-88): a "High
/// contrast" toggle (a `keepOpenOnSelect` item that live-applies the `-hc`
/// sibling, T-237) then the base themes — the `-hc` variants collapse into the
/// toggle. ClideMenu owns the arrow / Enter / Esc nav + autofocus; this widget
/// just maps theme state to entries and re-applies on select.
class _ThemePopover extends StatefulWidget {
  const _ThemePopover({required this.controller, required this.onClose});

  final ThemeController controller;
  final VoidCallback onClose;

  @override
  State<_ThemePopover> createState() => _ThemePopoverState();
}

class _ThemePopoverState extends State<_ThemePopover> {
  late bool _hc;

  List<ThemeDefinition> get _themes => baseThemes(widget.controller.available);

  @override
  void initState() {
    super.initState();
    _hc = isHcName(widget.controller.currentName);
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

  @override
  Widget build(BuildContext context) {
    final currentBase = baseThemeName(widget.controller.currentName);
    return Semantics(
      container: true,
      label: 'Theme switcher',
      explicitChildNodes: true,
      child: ClideMenu(
        onClose: widget.onClose,
        minWidth: 220,
        maxWidth: 280,
        maxHeight: 360,
        entries: [
          ClideMenuItem(
            label: 'High contrast',
            active: _hc,
            keepOpenOnSelect: true,
            onSelect: _toggleHc,
          ),
          const ClideMenuSeparator(),
          for (final t in _themes)
            ClideMenuItem(
              label: t.displayName,
              active: t.name == currentBase,
              onSelect: () => _pick(t),
            ),
        ],
      ),
    );
  }
}
