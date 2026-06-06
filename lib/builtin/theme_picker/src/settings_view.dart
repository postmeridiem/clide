import 'package:clide/builtin/theme_picker/src/theme_families.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// The ⌘K settings modal. Promoted from the old theme-only picker (T-238): a
/// general Settings surface that today holds a single **Appearance** section —
/// the theme list. Like the status-bar popover (T-237) it shows base themes
/// only (sorted) with a "High contrast" toggle that maps to the `-hc` sibling
/// (D-69); the shared `theme_families` helpers keep both surfaces in sync.
/// Selecting a theme applies it live and dismisses; Cancel just closes.
class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.controller,
    required this.onDismiss,
  });

  final ThemeController controller;
  final void Function([String? selected]) onDismiss;

  static const ns = 'builtin.theme-picker';

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String? _hovered;
  late bool _hc;

  @override
  void initState() {
    super.initState();
    _hc = isHcName(widget.controller.currentName);
  }

  void _toggleHc() {
    setState(() => _hc = !_hc);
    // Re-apply the current base with the new variant, live.
    final base = baseThemeName(widget.controller.currentName);
    widget.controller.select(resolveThemeName(widget.controller.available, base, highContrast: _hc));
  }

  void _pick(ThemeDefinition base) {
    widget.controller.select(resolveThemeName(widget.controller.available, base.name, highContrast: _hc));
    widget.onDismiss(base.name);
  }

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    final i = kernel.i18n;
    final themes = baseThemes(widget.controller.available);
    final currentBase = baseThemeName(widget.controller.currentName);
    final title = i.string('modal.title', namespace: SettingsView.ns, placeholder: 'Settings');

    return Semantics(
      container: true,
      label: title,
      explicitChildNodes: true,
      child: ClideSurface(
        width: 420,
        color: tokens.modalSurfaceBackground,
        border: tokens.modalSurfaceBorder,
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClideText(title, fontSize: 15, fontWeight: FontWeight.w600),
            const SizedBox(height: 8),
            ClideDivider(),
            const SizedBox(height: 12),
            // --- Appearance section (the only one for now) ---
            ClideText(
              i.string('section.appearance', namespace: SettingsView.ns, placeholder: 'Appearance'),
              fontSize: clideFontCaption,
              color: tokens.sidebarSectionHeader,
              fontFamily: clideMonoFamily,
            ),
            const SizedBox(height: 8),
            _HighContrastToggle(
              checked: _hc,
              label: i.string('toggle.highContrast', namespace: SettingsView.ns, placeholder: 'High contrast'),
              onTap: _toggleHc,
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in themes)
                      _ThemeRow(
                        name: t.name,
                        displayName: t.displayName,
                        selected: t.name == currentBase,
                        hovered: _hovered == t.name,
                        hint: i.string('row.select.hint', namespace: SettingsView.ns, placeholder: 'Activate this theme'),
                        onEnter: () => setState(() => _hovered = t.name),
                        onExit: () => setState(() => _hovered = null),
                        onTap: () => _pick(t),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ClideButton(
                  label: i.string('modal.cancel', namespace: SettingsView.ns, placeholder: 'Cancel'),
                  semanticHint: i.string('modal.cancel.hint', namespace: SettingsView.ns, placeholder: 'Close settings without changing anything'),
                  onPressed: () => widget.onDismiss(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "High contrast" checkbox row — toggles the `-hc` sibling for the current
/// theme (mirrors the status-bar popover's toggle).
class _HighContrastToggle extends StatefulWidget {
  const _HighContrastToggle({required this.checked, required this.label, required this.onTap});

  final bool checked;
  final String label;
  final VoidCallback onTap;

  @override
  State<_HighContrastToggle> createState() => _HighContrastToggleState();
}

class _HighContrastToggleState extends State<_HighContrastToggle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      checked: widget.checked,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            color: _hover ? tokens.listItemHoverBackground : null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: widget.checked ? tokens.buttonBackground : null,
                    border: Border.all(color: widget.checked ? tokens.buttonBackground : tokens.modalSurfaceBorder),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: widget.checked ? ClideIcon(const CheckIcon(), size: 9, color: tokens.buttonForeground) : null,
                ),
                const SizedBox(width: 8),
                Expanded(child: ClideText(widget.label, color: tokens.listItemForeground)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.name,
    required this.displayName,
    required this.selected,
    required this.hovered,
    required this.hint,
    required this.onEnter,
    required this.onExit,
    required this.onTap,
  });

  final String name;
  final String displayName;
  final bool selected;
  final bool hovered;
  final String hint;
  final VoidCallback onEnter;
  final VoidCallback onExit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final bg = selected ? tokens.listItemSelectedBackground : (hovered ? tokens.listItemHoverBackground : tokens.listItemBackground);
    final fg = selected ? tokens.listItemSelectedForeground : tokens.listItemForeground;
    return Semantics(
      button: true,
      selected: selected,
      label: displayName,
      hint: hint,
      onTap: onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onEnter(),
        onExit: (_) => onExit(),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            color: bg,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClideIcon(const CheckIcon(), size: 12, color: fg),
                  )
                else
                  const SizedBox(width: 20),
                Expanded(
                  child: ClideText(displayName, color: fg),
                ),
                ClideText(name, color: tokens.globalTextMuted, fontSize: clideFontCaption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
