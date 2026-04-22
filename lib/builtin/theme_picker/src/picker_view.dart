import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ThemePickerView extends StatefulWidget {
  const ThemePickerView({
    super.key,
    required this.controller,
    required this.onDismiss,
  });

  final ThemeController controller;
  final void Function([String? selected]) onDismiss;

  static const ns = 'builtin.theme-picker';

  @override
  State<ThemePickerView> createState() => _ThemePickerViewState();
}

class _ThemePickerViewState extends State<ThemePickerView> {
  String? _hovered;

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    final themes = widget.controller.available;
    final currentName = widget.controller.currentName;
    final i = kernel.i18n;

    return Semantics(
      container: true,
      label: i.string('modal.title',
          namespace: ThemePickerView.ns, placeholder: 'Select theme'),
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
            ClideText(
              i.string('modal.title',
                  namespace: ThemePickerView.ns, placeholder: 'Select theme'),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            const SizedBox(height: 8),
            ClideDivider(),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in themes)
                      _ThemeRow(
                        name: t.name,
                        displayName: t.displayName,
                        selected: t.name == currentName,
                        hovered: _hovered == t.name,
                        hint: i.string('row.select.hint',
                            namespace: ThemePickerView.ns,
                            placeholder: 'Activate this theme'),
                        onEnter: () => setState(() => _hovered = t.name),
                        onExit: () => setState(() => _hovered = null),
                        onTap: () {
                          widget.controller.select(t.name);
                          widget.onDismiss(t.name);
                        },
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
                  label: i.string('modal.cancel',
                      namespace: ThemePickerView.ns, placeholder: 'Cancel'),
                  semanticHint: i.string('modal.cancel.hint',
                      namespace: ThemePickerView.ns,
                      placeholder:
                          'Close the theme picker without changing the current theme'),
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
    final bg = selected
        ? tokens.listItemSelectedBackground
        : (hovered
            ? tokens.listItemHoverBackground
            : tokens.listItemBackground);
    final fg = selected
        ? tokens.listItemSelectedForeground
        : tokens.listItemForeground;
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
