import 'package:clide/clide.dart';
import 'package:clide_app/kernel/src/panels/slot_id.dart';
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
  const StatusItemContribution({
    required super.id,
    required this.build,
    this.priority = 0,
    this.listenable,
  });

  @override
  SlotId get slot => Slots.statusbar;
  final WidgetBuilder build;
  final int priority;
  final Listenable? listenable;
}

/// A button in the main toolbar.
class ToolbarButtonContribution extends ContributionPoint {
  const ToolbarButtonContribution({
    required super.id,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    this.priority = 0,
  });

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
  const CommandContribution({
    required super.id,
    required this.command,
    required this.run,
    this.title,
    this.defaultBinding,
  });

  final String command; // e.g. "git.commit"
  final String? title; // "Git: Commit staged"
  final String? defaultBinding; // e.g. "ctrl+shift+g"
  final Future<IpcResponse> Function(List<String> args) run;
}

/// Registers an item in the OS tray / menu-bar.
class TrayItemContribution extends ContributionPoint {
  const TrayItemContribution({
    required super.id,
    required this.label,
    required this.onSelected,
    this.priority = 0,
  });

  @override
  SlotId get slot => Slots.tray;
  final String label;
  final int priority;
  final VoidCallback onSelected;
}

/// A named layout arrangement. One "classic" preset ships with
/// `builtin.default-layout`; other presets can be contributed.
class LayoutPresetContribution extends ContributionPoint {
  const LayoutPresetContribution({
    required super.id,
    required this.displayName,
    required this.slots,
  });

  final String displayName;
  final List<LayoutSlot> slots;
}

/// One slot in a [LayoutPresetContribution]. Describes where the slot
/// appears and its initial size/visibility.
class LayoutSlot {
  const LayoutSlot({
    required this.slot,
    required this.position,
    this.defaultSize,
    this.minSize,
    this.maxSize,
    this.visible = true,
  });

  final SlotId slot;
  final SlotPosition position;
  final double? defaultSize;
  final double? minSize;
  final double? maxSize;
  final bool visible;
}
