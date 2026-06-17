/// Schema model for the settings panel (T-448, epic T-444).
///
/// Pure data — no Flutter imports — so any subsystem can declare a category
/// without depending on the widget layer. The settings-ui renderer turns a
/// [SettingsCategory] into carded sections of field rows; each field binds to
/// a `SettingsStore` key and is read/written through the store.
library;

/// The control a [SettingsField] renders as.
enum SettingsFieldKind {
  /// On/off boolean.
  toggle,

  /// One value chosen from [SettingsField.options].
  select,

  /// Free-text input.
  text,

  /// Numeric input (optionally bounded by [SettingsField.min]/[max]).
  number,

  /// A row that opens an external file/editor (e.g. `.editorconfig`) instead
  /// of editing a value inline — the action is a command id, keeping the
  /// schema widget-free.
  file,
}

/// One choice in a [SettingsFieldKind.select] field.
class SettingsOption {
  const SettingsOption({required this.value, required this.label});

  /// Stored value.
  final String value;

  /// Human label shown in the picker.
  final String label;
}

/// One editable setting. [key] is a `SettingsStore` key — its `app.`/
/// `project.`/`ext.` prefix determines the scope (and the per-field scope tag,
/// T-449). The renderer reads the current value with `store.get`, falling back
/// to [defaultValue] when unset, and writes edits with `store.set`.
class SettingsField {
  const SettingsField({
    required this.key,
    required this.kind,
    required this.label,
    this.help,
    this.defaultValue,
    this.options = const [],
    this.min,
    this.max,
    this.fileCommand,
    this.applyCommandPrefix,
  });

  final String key;
  final SettingsFieldKind kind;
  final String label;

  /// Optional one-line help shown under the label.
  final String? help;

  /// Value shown / restored when the key is unset (reset-to-default target).
  final Object? defaultValue;

  /// Choices for [SettingsFieldKind.select].
  final List<SettingsOption> options;

  /// Optional inclusive bounds for [SettingsFieldKind.number].
  final num? min;
  final num? max;

  /// For [SettingsFieldKind.file]: the command id the row's button invokes.
  final String? fileCommand;

  /// For [SettingsFieldKind.select]: when set, picking option `<value>` runs
  /// the command `<applyCommandPrefix><value>` instead of writing [key]
  /// directly — for settings a subsystem applies via a command (and only then
  /// persists). The current value is still read from [key], so the scope tag
  /// and selection still work. Example: `'keymap.preset.'` → `keymap.preset.vim`.
  final String? applyCommandPrefix;
}

/// A carded group of fields (surface.md "sectioned cards"). [label] is the
/// small-caps header rendered just above the card.
class SettingsSection {
  const SettingsSection({required this.label, required this.fields});

  final String label;
  final List<SettingsField> fields;
}

/// One settings category — a rail entry (T-447) plus the sections its panel
/// shows. Subsystems register these via `SettingsCategoryContribution`; the
/// renderer draws them.
class SettingsCategory {
  const SettingsCategory({required this.id, required this.title, required this.sections, this.iconName, this.priority = 0});

  final String id;
  final String title;

  /// Phosphor glyph name, resolved via `PhosphorIcons.byName` at render (T-314).
  final String? iconName;

  /// Rail ordering — lower sorts first; ties broken by [title].
  final int priority;

  final List<SettingsSection> sections;
}
