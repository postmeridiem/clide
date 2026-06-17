import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// The schema-driven field renderer (T-448, epic T-444): turns a
/// [SettingsCategory] into carded sections of field rows. Each field binds to a
/// `SettingsStore` key — read with `get` (falling back to the schema default),
/// written with `set` on edit. Rebuilds live as the store changes.
///
/// Per-field scope tags (T-449) and cross-category search (T-450) layer onto
/// the row in their own tickets; the trailing slot here is the reset control.
/// Carded layout follows ui-design `surface.md` ("sectioned cards").
class SettingsCategoryView extends StatelessWidget {
  const SettingsCategoryView({super.key, required this.category});

  final SettingsCategory category;

  @override
  Widget build(BuildContext context) {
    final store = ClideKernel.of(context).settings;
    // Re-read on every settings change so edits (and resets) reflect at once.
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in category.sections) _SectionCard(section: section, store: store),
          ],
        ),
      ),
    );
  }
}

/// One section: a small-caps header above an elevated card of field rows.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.store});

  final SettingsSection section;
  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: ClideText(
              section.label.toUpperCase(),
              fontSize: clideFontCaption,
              color: tokens.sidebarSectionHeader,
              fontFamily: clideMonoFamily,
            ),
          ),
          ClideSurface(
            // Card surface (surface.md): panelHeader resolves to the `surface`
            // palette key (the elevated card tone); inputs inside recede to
            // panelBackground.
            color: tokens.panelHeader,
            border: tokens.dividerColor,
            borderRadius: BorderRadius.circular(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < section.fields.length; i++) ...[
                  if (i > 0) const ClideDivider(),
                  _FieldRow(field: section.fields[i], store: store),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A label/help block + the field's control + a reset affordance.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.field, required this.store});

  final SettingsField field;
  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final raw = store.get<Object>(field.key);
    final effective = raw ?? field.defaultValue;
    final canReset = field.defaultValue != null && effective != field.defaultValue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClideText(field.label, color: tokens.globalForeground),
                if (field.help != null && field.help!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: ClideText(field.help!, fontSize: clideFontCaption, color: tokens.globalTextMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _Control(field: field, value: effective, store: store),
          SizedBox(
            width: 24,
            child: canReset
                ? _ResetButton(onTap: () => store.set<Object?>(field.key, field.defaultValue))
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Dispatches to the control widget for the field's [SettingsFieldKind].
class _Control extends StatelessWidget {
  const _Control({required this.field, required this.value, required this.store});

  final SettingsField field;
  final Object? value;
  final SettingsStore store;

  void _set(Object? v) => store.set<Object?>(field.key, v);

  @override
  Widget build(BuildContext context) {
    switch (field.kind) {
      case SettingsFieldKind.toggle:
        return _ToggleControl(checked: value == true, onChanged: _set);
      case SettingsFieldKind.select:
        return _SelectControl(field: field, value: value?.toString(), onPick: _set);
      case SettingsFieldKind.text:
        return _EditControl(field: field, value: value?.toString() ?? '', numeric: false, onCommit: _set);
      case SettingsFieldKind.number:
        return _EditControl(field: field, value: value?.toString() ?? '', numeric: true, onCommit: _set);
      case SettingsFieldKind.file:
        return _FileControl(field: field);
    }
  }
}

/// Checkbox toggle (mirrors the theme-picker high-contrast box).
class _ToggleControl extends StatelessWidget {
  const _ToggleControl({required this.checked, required this.onChanged});

  final bool checked;
  final void Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      checked: checked,
      excludeSemantics: true,
      child: ClideTappable(
        cursor: SystemMouseCursors.click,
        onTap: () => onChanged(!checked),
        builder: (ctx, hovered, pressed) => Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: checked ? tokens.buttonBackground : (hovered ? tokens.listItemHoverBackground : null),
            border: Border.all(color: checked ? tokens.buttonBackground : tokens.modalSurfaceBorder),
            borderRadius: BorderRadius.circular(3),
          ),
          child: checked ? ClideIcon(const CheckIcon(), size: 11, color: tokens.buttonForeground) : null,
        ),
      ),
    );
  }
}

/// Enum picker — current value on an anchored popover of options.
class _SelectControl extends StatefulWidget {
  const _SelectControl({required this.field, required this.value, required this.onPick});

  final SettingsField field;
  final String? value;
  final void Function(String value) onPick;

  @override
  State<_SelectControl> createState() => _SelectControlState();
}

class _SelectControlState extends State<_SelectControl> {
  final ClideOverlayController _overlay = ClideOverlayController();

  @override
  void dispose() {
    _overlay.dispose();
    super.dispose();
  }

  String get _label {
    for (final o in widget.field.options) {
      if (o.value == widget.value) return o.label;
    }
    return widget.value ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return ClideAnchoredOverlay(
      controller: _overlay,
      align: ClideAnchorAlign.end,
      overlayBuilder: (ctx, c) => ClideMenu(
        onClose: c.close,
        entries: [
          for (final o in widget.field.options)
            ClideMenuItem(
              label: o.label,
              active: o.value == widget.value,
              semanticLabel: '${widget.field.label}: ${o.label}',
              onSelect: () => widget.onPick(o.value),
            ),
        ],
      ),
      anchor: Semantics(
        button: true,
        label: '${widget.field.label}: $_label. Click to change.',
        excludeSemantics: true,
        onTap: _overlay.toggle,
        child: ClideTappable(
          cursor: SystemMouseCursors.click,
          onTap: _overlay.toggle,
          builder: (ctx, hovered, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              border: Border.all(color: hovered ? tokens.panelActiveBorder : tokens.dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClideText(_label, color: tokens.globalForeground),
                const SizedBox(width: 6),
                ClideIcon(PhosphorIcons.byName('caret-down'), size: 10, color: tokens.globalTextMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline text / numeric editor. Commits on Enter and on focus loss; numeric
/// fields parse + clamp to the field's bounds, ignoring unparseable input.
class _EditControl extends StatefulWidget {
  const _EditControl({required this.field, required this.value, required this.numeric, required this.onCommit});

  final SettingsField field;
  final String value;
  final bool numeric;
  final void Function(Object value) onCommit;

  @override
  State<_EditControl> createState() => _EditControlState();
}

class _EditControlState extends State<_EditControl> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  late final FocusNode _focus = FocusNode(debugLabel: 'settings-${widget.field.key}');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_EditControl old) {
    super.didUpdateWidget(old);
    // Reflect external changes (reset, scope flip) only when not being edited.
    if (!_focus.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final text = _controller.text.trim();
    if (widget.numeric) {
      final n = num.tryParse(text);
      if (n == null) {
        _controller.text = widget.value; // revert unparseable input
        return;
      }
      var clamped = n;
      final min = widget.field.min;
      final max = widget.field.max;
      if (min != null && clamped < min) clamped = min;
      if (max != null && clamped > max) clamped = max;
      // Preserve int vs double per the parsed text.
      final out = clamped == clamped.roundToDouble() && !text.contains('.') ? clamped.toInt() : clamped;
      _controller.text = '$out';
      widget.onCommit(out);
    } else {
      widget.onCommit(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      textField: true,
      label: widget.field.label,
      excludeSemantics: true,
      child: Container(
        width: widget.numeric ? 88 : 180,
        height: 26,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          border: Border.all(color: _focus.hasFocus ? tokens.panelActiveBorder : tokens.dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: EditableText(
          controller: _controller,
          focusNode: _focus,
          style: TextStyle(fontFamily: clideMonoFamily, fontSize: clideFontMono, color: tokens.globalForeground),
          cursorColor: tokens.globalFocus,
          backgroundCursorColor: tokens.globalTextMuted,
          maxLines: 1,
          onSubmitted: (_) => _commit(),
        ),
      ),
    );
  }
}

/// "Opens external file" affordance — a button that runs the field's command.
class _FileControl extends StatelessWidget {
  const _FileControl({required this.field});

  final SettingsField field;

  @override
  Widget build(BuildContext context) {
    final commands = ClideKernel.of(context).commands;
    return ClideButton(
      label: field.label,
      variant: ClideButtonVariant.subtle,
      onPressed: field.fileCommand == null ? null : () => commands.execute(field.fileCommand!),
    );
  }
}

/// Reset-to-default control — a circular-arrow icon shown when the value
/// differs from the schema default.
class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      button: true,
      label: 'Reset to default',
      excludeSemantics: true,
      child: ClideTappable(
        cursor: SystemMouseCursors.click,
        tooltip: 'Reset to default',
        onTap: onTap,
        builder: (ctx, hovered, _) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: ClideIcon(
            PhosphorIcons.byName('arrow-counter-clockwise'),
            size: 14,
            color: hovered ? tokens.globalForeground : tokens.globalTextMuted,
          ),
        ),
      ),
    );
  }
}
