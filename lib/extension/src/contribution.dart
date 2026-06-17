import 'package:clide/clide.dart';
import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:clide/kernel/src/settings_schema.dart';
import 'package:flutter/widgets.dart';

/// One atom contributed by a [ClideExtension]. Extensions declare N of
/// these in a manifest; the kernel and slot hosts render them.
///
/// Adding a new contribution type: add a case to this sealed hierarchy,
/// extend the host dispatch in the default-layout extension, and bump
/// the extension manifest schema version.
sealed class ContributionPoint {
  const ContributionPoint({required this.id});

  /// Stable id for this contribution, unique within its extension.
  final String id;

  /// The slot this contribution targets, or `null` for non-slot
  /// contributions (commands, events, grammars).
  SlotId? get slot => null;
}

/// A tab in a slot that hosts tabs (sidebar / workspace / context).
class TabContribution extends ContributionPoint {
  const TabContribution({
    required super.id,
    required this.slot,
    required this.title,
    required this.build,
    this.icon,
    this.iconColor,
    this.priority = 0,
    this.fileGlobs = const [],
    this.listenable,
    this.titleKey,
    this.i18nNamespace,
  });

  @override
  final SlotId slot;
  final String title;
  final WidgetBuilder build;
  final Object? icon;

  /// Optional identity tint for the icon-rail glyph (T-418).
  final Color? iconColor;
  final int priority;
  final List<String> fileGlobs;
  final Listenable? listenable;

  /// When set, the slot host resolves the display title via
  /// `i18n.string(titleKey, namespace: i18nNamespace, placeholder: title)`.
  /// [title] stays as the English fallback (also used in tests/logs).
  final String? titleKey;

  /// The i18n namespace to look up [titleKey] in. Extensions usually
  /// pass their own `id`. Required when [titleKey] is set.
  final String? i18nNamespace;
}

/// A status-bar item. Order is determined by [priority] within each
/// alignment group; negative priorities float left, positive right.
class StatusItemContribution extends ContributionPoint {
  const StatusItemContribution({required super.id, required this.build, this.priority = 0, this.listenable, this.flex = 0});

  @override
  SlotId get slot => Slots.statusbar;
  final WidgetBuilder build;
  final int priority;
  final Listenable? listenable;

  /// When > 0, the status bar wraps this item in
  /// `Flexible(flex: flex, fit: FlexFit.loose)` so it yields width when the
  /// bar is tight and any contained [ClideMarquee] can scroll (T-160).
  /// Defaults to 0 (intrinsic/non-flex). Only meaningful for left-side items
  /// (priority < 100); right-side items are always intrinsic-width.
  final int flex;
}

/// A button in the main toolbar.
class ToolbarButtonContribution extends ContributionPoint {
  const ToolbarButtonContribution({required super.id, required this.label, required this.onPressed, this.icon, this.tooltip, this.priority = 0});

  @override
  SlotId get slot => Slots.toolbar;
  final String label;
  final Object? icon;
  final String? tooltip;
  final int priority;
  final VoidCallback onPressed;
}

/// A command extensions register with [CommandRegistry]. Surfaced by the
/// command palette, the keybinding resolver, and `clide` CLI subcommands.
class CommandContribution extends ContributionPoint {
  const CommandContribution({required super.id, required this.command, required this.run, this.title, this.defaultBinding, this.bindingWhen});

  final String command; // e.g. "git.commit"
  final String? title; // "Git: Commit staged"
  final String? defaultBinding; // e.g. "ctrl+shift+g"

  /// Optional when-clause guarding [defaultBinding] (same grammar as keymap
  /// YAML `when:`). Lets a global binding yield to a higher-context one — e.g.
  /// `panel.focusMode.exit`'s `escape` stands down in Vim insert/visual mode so
  /// the preset's `vim.mode.normal` wins (T-257). Null → binding always active.
  final String? bindingWhen;
  final Future<IpcResponse> Function(List<String> args) run;
}

/// Registers an item in the OS tray / menu-bar.
class TrayItemContribution extends ContributionPoint {
  const TrayItemContribution({required super.id, required this.label, required this.onSelected, this.priority = 0});

  @override
  SlotId get slot => Slots.tray;
  final String label;
  final int priority;
  final VoidCallback onSelected;
}

/// A named layout arrangement. One "classic" preset ships with
/// `builtin.default-layout`; other presets can be contributed.
class LayoutPresetContribution extends ContributionPoint {
  const LayoutPresetContribution({required super.id, required this.displayName, required this.slots});

  final String displayName;
  final List<LayoutSlot> slots;
}

/// One slot in a [LayoutPresetContribution]. Describes where the slot
/// appears and its initial size/visibility.
class LayoutSlot {
  const LayoutSlot({required this.slot, required this.position, this.defaultSize, this.minSize, this.maxSize, this.visible = true});

  final SlotId slot;
  final SlotPosition position;
  final double? defaultSize;
  final double? minSize;
  final double? maxSize;
  final bool visible;
}

/// A category in the Settings panel (epic T-444). The kernel routes it into the
/// `SettingsRegistry`; `builtin.settings-ui` renders its [SettingsCategory]
/// schema into carded field rows (T-448). Categories are data — register one to
/// surface a new settings tab.
class SettingsCategoryContribution extends ContributionPoint {
  const SettingsCategoryContribution({required super.id, required this.category});

  final SettingsCategory category;
}

/// A bespoke widget for a `SettingsFieldKind.custom` field (T-452). The kernel
/// routes it into the `SettingsControlRegistry` under [customId]; the settings
/// renderer draws it when a field names that [customId]. Lets a subsystem ship
/// a one-off control (e.g. the theme picker) without leaking widgets into the
/// pure-data schema.
class SettingsControlContribution extends ContributionPoint {
  const SettingsControlContribution({required super.id, required this.customId, required this.builder});

  final String customId;
  final WidgetBuilder builder;
}
