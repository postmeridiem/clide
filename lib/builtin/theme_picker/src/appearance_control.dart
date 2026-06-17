import 'package:clide/builtin/theme_picker/src/theme_families.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// The Appearance category's custom theme control (T-452) — the one bespoke
/// settings control the schema engine defers to (registered as
/// `SettingsControlContribution('theme.picker')`).
///
/// Base themes render as selectable chips; a High-contrast toggle maps to the
/// `-hc` sibling (D-69) via the shared [theme_families] helpers. Selecting
/// applies live through [ThemeController] (which persists via theme_persistence)
/// — so this control owns its own apply + scope, unlike schema-keyed fields.
class AppearanceThemeControl extends StatelessWidget {
  const AppearanceThemeControl({super.key});

  static const ns = 'builtin.theme-picker';

  @override
  Widget build(BuildContext context) {
    final controller = ClideKernel.of(context).theme;
    final i = ClideSettings.i18n.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final themes = baseThemes(controller.available);
        final currentBase = baseThemeName(controller.currentName);
        final hc = isHcName(controller.currentName);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in themes)
                  _ThemeChip(
                    label: t.displayName,
                    selected: t.name == currentBase,
                    onTap: () => controller.select(resolveThemeName(controller.available, t.name, highContrast: hc)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _HcToggle(
              checked: hc,
              label: i.string('toggle.highContrast', namespace: ns, placeholder: 'High contrast'),
              onTap: () => controller.select(resolveThemeName(controller.available, currentBase, highContrast: !hc)),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: ClideTappable(
        cursor: SystemMouseCursors.click,
        onTap: onTap,
        builder: (ctx, hovered, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? tokens.buttonActiveBackground : (hovered ? tokens.listItemHoverBackground : tokens.panelBackground),
            border: Border.all(color: selected ? tokens.panelActiveBorder : tokens.dividerColor),
            borderRadius: BorderRadius.circular(5),
          ),
          child: ClideText(label, color: selected ? tokens.globalBackground : tokens.globalForeground),
        ),
      ),
    );
  }
}

class _HcToggle extends StatelessWidget {
  const _HcToggle({required this.checked, required this.label, required this.onTap});

  final bool checked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      checked: checked,
      label: label,
      excludeSemantics: true,
      child: ClideTappable(
        cursor: SystemMouseCursors.click,
        onTap: onTap,
        builder: (ctx, hovered, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: checked ? tokens.buttonBackground : (hovered ? tokens.listItemHoverBackground : null),
                border: Border.all(color: checked ? tokens.buttonBackground : tokens.modalSurfaceBorder),
                borderRadius: BorderRadius.circular(3),
              ),
              child: checked ? ClideIcon(const CheckIcon(), size: 11, color: tokens.buttonForeground) : null,
            ),
            const SizedBox(width: 8),
            ClideText(label, color: tokens.listItemForeground),
          ],
        ),
      ),
    );
  }
}
