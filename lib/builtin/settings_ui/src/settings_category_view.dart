import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// i18n namespace shared with the settings modal shell.
const _settingsNs = 'builtin.settings-ui';

/// Resolve a schema label through the catalog under the owning category's
/// [namespace], falling back to the English [english] label when the [key] is
/// null or the [namespace] is null/empty (T-462). Short-circuiting before the
/// lookup keeps key-less categories warning-free and pixel-identical.
String _localized(BuildContext context, String? key, String? namespace, String english) {
  if (key == null || namespace == null || namespace.isEmpty) return english;
  return ClideSettings.i18n.string(context, key, namespace: namespace, placeholder: english);
}

/// The schema-driven field renderer (T-448, epic T-444): turns a
/// [SettingsCategory] into carded sections of field rows. Each field binds to a
/// `SettingsStore` key — read with `get` (falling back to the schema default),
/// written with `set` on edit. Rebuilds live as the store changes.
///
/// Each row ends in a per-field scope tag (T-449) whose menu also resets the
/// value; cross-category search lives in [SettingsSearchResults] (T-450).
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
          children: [for (final section in category.sections) _SectionCard(section: section, store: store, i18nNamespace: category.i18nNamespace)],
        ),
      ),
    );
  }
}

/// True when [field] matches [query] (case-insensitive; label or help). An
/// empty query matches everything.
///
/// Context-free: matches the English label/help only — display localizes the
/// shown text, but search-by-translation is out of scope (T-462).
bool settingsFieldMatches(SettingsField field, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return field.label.toLowerCase().contains(q) || (field.help?.toLowerCase().contains(q) ?? false);
}

/// [category]'s sections holding only the fields matching [query]; empty
/// sections are dropped.
List<SettingsSection> settingsMatchingSections(SettingsCategory category, String query) {
  final out = <SettingsSection>[];
  for (final s in category.sections) {
    final fields = s.fields.where((f) => settingsFieldMatches(f, query)).toList();
    // Carry labelKey so search-result section headers still localize (T-462).
    if (fields.isNotEmpty) out.add(SettingsSection(label: s.label, fields: fields, labelKey: s.labelKey));
  }
  return out;
}

/// How many fields in [category] match [query] (the rail's per-category count).
int settingsMatchCount(SettingsCategory category, String query) =>
    category.sections.fold(0, (n, s) => n + s.fields.where((f) => settingsFieldMatches(f, query)).length);

/// Cross-category search results (T-450): every matching field across ALL
/// registered categories, grouped under a category subheader, rendered with the
/// same carded field rows and editable inline.
class SettingsSearchResults extends StatelessWidget {
  const SettingsSearchResults({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final i = ClideSettings.i18n.of(context);
    final store = ClideKernel.of(context).settings;
    final registry = ClideKernel.of(context).settingsRegistry;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final blocks = <Widget>[];
        for (final c in registry.categories) {
          final sections = settingsMatchingSections(c, query);
          if (sections.isEmpty) continue;
          blocks.add(
            Padding(
              padding: EdgeInsets.only(top: blocks.isEmpty ? 0 : 14, bottom: 8),
              child: ClideText(
                _localized(context, c.titleKey, c.i18nNamespace, c.title),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.globalForeground,
              ),
            ),
          );
          for (final s in sections) {
            blocks.add(_SectionCard(section: s, store: store, i18nNamespace: c.i18nNamespace));
          }
        }
        if (blocks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ClideText(
                i.string('search.empty', namespace: _settingsNs, placeholder: 'No settings match your search.'),
                color: tokens.globalTextMuted,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks),
        );
      },
    );
  }
}

/// One section: a small-caps header above an elevated card of field rows.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.store, this.i18nNamespace});

  final SettingsSection section;
  final SettingsStore store;

  /// Owning category's i18n namespace (T-462); null for key-less categories.
  final String? i18nNamespace;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final sectionLabel = _localized(context, section.labelKey, i18nNamespace, section.label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sectionLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: ClideText(
                sectionLabel.toUpperCase(),
                fontSize: clideFontCaption,
                color: tokens.sidebarSectionHeader,
                fontFamily: ClideSettings.fonts.monoOf(context),
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
                  _FieldRow(field: section.fields[i], store: store, i18nNamespace: i18nNamespace),
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
  const _FieldRow({required this.field, required this.store, this.i18nNamespace});

  final SettingsField field;
  final SettingsStore store;

  /// Owning category's i18n namespace (T-462); null for key-less categories.
  final String? i18nNamespace;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final fieldLabel = _localized(context, field.labelKey, i18nNamespace, field.label);
    final fieldHelp = field.help == null ? null : _localized(context, field.helpKey, i18nNamespace, field.help!);
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClideText(fieldLabel, color: tokens.globalForeground),
        if (fieldHelp != null && fieldHelp.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ClideText(fieldHelp, fontSize: clideFontCaption, color: tokens.globalTextMuted),
          ),
      ],
    );

    // Custom controls own their layout, persistence, and scope — render them
    // full-width under the label rather than in the narrow control slot.
    if (field.kind == SettingsFieldKind.custom) {
      final id = field.customId;
      final builder = id == null ? null : ClideKernel.of(context).settingsControlRegistry.builderFor(id);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fieldLabel.isNotEmpty) ...[label, const SizedBox(height: 10)],
            builder?.call(context) ?? const SizedBox.shrink(),
          ],
        ),
      );
    }

    final raw = store.get<Object>(field.key);
    final effective = raw ?? field.defaultValue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: label),
          const SizedBox(width: 16),
          _Control(field: field, value: effective, store: store, i18nNamespace: i18nNamespace),
          const SizedBox(width: 10),
          _ScopeTag(field: field, store: store, effectiveValue: effective, i18nNamespace: i18nNamespace),
        ],
      ),
    );
  }
}

/// Dispatches to the control widget for the field's [SettingsFieldKind].
class _Control extends StatelessWidget {
  const _Control({required this.field, required this.value, required this.store, this.i18nNamespace});

  final SettingsField field;
  final Object? value;
  final SettingsStore store;

  /// Owning category's i18n namespace (T-462); null for key-less categories.
  final String? i18nNamespace;

  void _set(Object? v) => store.set<Object?>(field.key, v);

  @override
  Widget build(BuildContext context) {
    switch (field.kind) {
      case SettingsFieldKind.toggle:
        return _ToggleControl(checked: value == true, onChanged: _set);
      case SettingsFieldKind.select:
        return _SelectControl(
          field: field,
          value: value?.toString(),
          i18nNamespace: i18nNamespace,
          onPick: (v) {
            final prefix = field.applyCommandPrefix;
            if (prefix != null) {
              // Value selects a command (the subsystem applies + persists).
              ClideKernel.of(context).commands.execute('$prefix$v');
            } else {
              _set(v);
            }
          },
        );
      case SettingsFieldKind.text:
        return _EditControl(field: field, value: value?.toString() ?? '', numeric: false, i18nNamespace: i18nNamespace, onCommit: _set);
      case SettingsFieldKind.number:
        return _EditControl(field: field, value: value?.toString() ?? '', numeric: true, i18nNamespace: i18nNamespace, onCommit: _set);
      case SettingsFieldKind.file:
        return _FileControl(field: field, i18nNamespace: i18nNamespace);
      case SettingsFieldKind.custom:
        // Custom fields are rendered full-width by _FieldRow; never here.
        return const SizedBox.shrink();
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
    final tokens = ClideSettings.theme.of(context).surface;
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
  const _SelectControl({required this.field, required this.value, required this.onPick, this.i18nNamespace});

  final SettingsField field;
  final String? value;
  final void Function(String value) onPick;

  /// Owning category's i18n namespace (T-462); null for key-less categories.
  final String? i18nNamespace;

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

  /// Localized label for the currently selected option (or the raw value).
  String _selectedLabel(BuildContext context) {
    for (final o in widget.field.options) {
      if (o.value == widget.value) return _localized(context, o.labelKey, widget.i18nNamespace, o.label);
    }
    return widget.value ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final fieldLabel = _localized(context, widget.field.labelKey, widget.i18nNamespace, widget.field.label);
    final selectedLabel = _selectedLabel(context);
    return ClideAnchoredOverlay(
      controller: _overlay,
      align: ClideAnchorAlign.end,
      overlayBuilder: (ctx, c) => ClideMenu(
        onClose: c.close,
        entries: [
          for (final o in widget.field.options)
            ClideMenuItem(
              label: _localized(context, o.labelKey, widget.i18nNamespace, o.label),
              active: o.value == widget.value,
              semanticLabel: '$fieldLabel: ${_localized(context, o.labelKey, widget.i18nNamespace, o.label)}',
              onSelect: () => widget.onPick(o.value),
            ),
        ],
      ),
      anchor: Semantics(
        button: true,
        label: '$fieldLabel: $selectedLabel. Click to change.',
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
                ClideText(selectedLabel, color: tokens.globalForeground),
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
  const _EditControl({required this.field, required this.value, required this.numeric, required this.onCommit, this.i18nNamespace});

  final SettingsField field;
  final String value;
  final bool numeric;
  final void Function(Object value) onCommit;

  /// Owning category's i18n namespace (T-462); null for key-less categories.
  final String? i18nNamespace;

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
    final tokens = ClideSettings.theme.of(context).surface;
    return Semantics(
      textField: true,
      label: _localized(context, widget.field.labelKey, widget.i18nNamespace, widget.field.label),
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
          style: TextStyle(fontFamily: ClideSettings.fonts.monoOf(context), fontSize: clideFontMono, color: tokens.globalForeground),
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
  const _FileControl({required this.field, this.i18nNamespace});

  final SettingsField field;

  /// Owning category's i18n namespace (T-462); null for key-less categories.
  final String? i18nNamespace;

  @override
  Widget build(BuildContext context) {
    final commands = ClideKernel.of(context).commands;
    return ClideButton(
      label: _localized(context, field.labelKey, i18nNamespace, field.label),
      variant: ClideButtonVariant.subtle,
      onPressed: field.fileCommand == null ? null : () => commands.execute(field.fileCommand!),
    );
  }
}

/// Per-field scope tag (T-449): a colour-coded glyph showing where the value
/// lives — folder = Project (`.clide`), globe = Always (`~/.clide`),
/// circle-dashed = Default/unset. Tapping opens a menu to move the value
/// between the scopes the key supports, or reset it to default.
///
/// Storage layering follows the SettingsStore key prefix: `ext.*` keys may
/// live in either file (project overrides app); `app.*`/`project.*` keys live
/// only in their prefix's layer, so their menu offers that one scope + reset.
class _ScopeTag extends StatefulWidget {
  const _ScopeTag({required this.field, required this.store, required this.effectiveValue, this.i18nNamespace});

  final SettingsField field;
  final SettingsStore store;
  final Object? effectiveValue;

  /// Owning category's i18n namespace (T-462); null for key-less categories.
  final String? i18nNamespace;

  @override
  State<_ScopeTag> createState() => _ScopeTagState();
}

class _ScopeTagState extends State<_ScopeTag> {
  final ClideOverlayController _overlay = ClideOverlayController();

  @override
  void dispose() {
    _overlay.dispose();
    super.dispose();
  }

  String _ns(String key, String fallback) => ClideSettings.i18n.of(context).string(key, namespace: _settingsNs, placeholder: fallback);

  ({String glyph, Color color, String tip, String label}) _appearance(SettingsScope? layer) {
    final tokens = ClideSettings.theme.of(context).surface;
    return switch (layer) {
      SettingsScope.project => (
        glyph: 'folder',
        color: tokens.statusSuccess,
        tip: _ns('scope.tip.project', 'Stored in this project (.clide)'),
        label: _ns('scope.project', 'This project'),
      ),
      SettingsScope.app => (
        glyph: 'globe',
        color: tokens.statusWarning,
        tip: _ns('scope.tip.always', 'Stored for all clide (~/.clide)'),
        label: _ns('scope.always', 'All clide'),
      ),
      _ => (
        glyph: 'circle-dashed',
        color: tokens.globalTextMuted,
        tip: _ns('scope.tip.default', 'Unset — using the default'),
        label: _ns('scope.default', 'Default'),
      ),
    };
  }

  /// Move the value into [layer], clearing it from the key's other layers.
  void _moveTo(SettingsScope layer) {
    final value = widget.store.get<Object>(widget.field.key) ?? widget.field.defaultValue;
    widget.store.setAt(layer, widget.field.key, value);
    for (final other in widget.store.writableLayers(widget.field.key)) {
      if (other != layer) widget.store.removeAt(other, widget.field.key);
    }
  }

  void _reset() {
    for (final layer in widget.store.writableLayers(widget.field.key)) {
      widget.store.removeAt(layer, widget.field.key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.store.effectiveLayer(widget.field.key);
    final look = _appearance(current);
    final layers = widget.store.writableLayers(widget.field.key);
    final fieldLabel = _localized(context, widget.field.labelKey, widget.i18nNamespace, widget.field.label);
    return ClideAnchoredOverlay(
      controller: _overlay,
      align: ClideAnchorAlign.end,
      overlayBuilder: (ctx, c) => ClideMenu(
        onClose: c.close,
        entries: [
          for (final layer in layers) ClideMenuItem(label: _appearance(layer).label, active: layer == current, onSelect: () => _moveTo(layer)),
          const ClideMenuSeparator(),
          ClideMenuItem(label: _ns('scope.reset', 'Reset to default'), active: false, enabled: current != null, onSelect: _reset),
        ],
      ),
      anchor: Semantics(
        button: true,
        label: '$fieldLabel scope: ${look.label}',
        excludeSemantics: true,
        onTap: _overlay.toggle,
        child: ClideTappable(
          cursor: SystemMouseCursors.click,
          tooltip: look.tip,
          onTap: _overlay.toggle,
          builder: (ctx, hovered, _) => Padding(
            padding: const EdgeInsets.all(2),
            child: ClideIcon(PhosphorIcons.byName(look.glyph), size: 15, color: look.color),
          ),
        ),
      ),
    );
  }
}
