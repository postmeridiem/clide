/// Menu model + resolver for the application menu bar (T-48).
///
/// The menu is **hybrid**: a hand-authored [TopMenu] tree fixes the curated
/// placement (ordering, grouping, separators), and a [MenuAutoFill] node sweeps
/// in any registered command sharing a prefix that wasn't explicitly placed.
/// Titles and keybindings are pulled from the [CommandRegistry] / keymap at
/// resolve time, so the menu always reflects the live command set. Items whose
/// command isn't registered, or whose [MenuCommandItem.enabledWhen] predicate
/// fails, resolve to **disabled** (greyed) — visible, never hidden.
library;

import 'package:clide/extension/extension.dart' show CommandContribution;
import 'package:clide/kernel/kernel.dart';

// ---------------------------------------------------------------------------
// Authoring model (the curated tree)
// ---------------------------------------------------------------------------

/// A node in a curated menu.
sealed class MenuNode {
  const MenuNode();
}

/// An explicit placement of a registry command. Title + keybinding come from
/// the registry at resolve time; [fallbackTitle] is used only when the command
/// isn't registered (in which case the item is disabled).
class MenuCommandItem extends MenuNode {
  const MenuCommandItem(this.commandId, {this.fallbackTitle, this.enabledWhen});
  final String commandId;
  final String? fallbackTitle;

  /// Extra enablement predicate (beyond "is registered"). When it returns
  /// false the item shows greyed. Used e.g. to grey "Close Project" when no
  /// project is open.
  final bool Function(KernelServices)? enabledWhen;
}

/// A horizontal rule between groups.
class MenuSeparator extends MenuNode {
  const MenuSeparator();
}

/// Sweep in every registered command whose id starts with [prefix] and isn't
/// explicitly placed elsewhere in the tree, sorted by title.
class MenuAutoFill extends MenuNode {
  const MenuAutoFill(this.prefix);
  final String prefix;
}

/// A top-level menu (File / View / Help).
class TopMenu {
  const TopMenu({required this.title, required this.mnemonic, required this.nodes});
  final String title;

  /// Index into [title] of the Alt-mnemonic letter (e.g. 0 → 'F' in "File").
  final int mnemonic;
  final List<MenuNode> nodes;

  /// The lower-case mnemonic character, for matching `Alt+<letter>`.
  String get mnemonicChar => title[mnemonic].toLowerCase();
}

// ---------------------------------------------------------------------------
// Resolved model (render-ready)
// ---------------------------------------------------------------------------

sealed class ResolvedNode {
  const ResolvedNode();
}

class ResolvedItem extends ResolvedNode {
  const ResolvedItem({required this.commandId, required this.title, required this.enabled, this.keybinding});
  final String commandId;
  final String title;
  final bool enabled;
  final String? keybinding;
}

class ResolvedSeparator extends ResolvedNode {
  const ResolvedSeparator();
}

class ResolvedMenu {
  const ResolvedMenu({required this.title, required this.mnemonic, required this.items});
  final String title;
  final int mnemonic;
  final List<ResolvedNode> items;
}

// ---------------------------------------------------------------------------
// Resolver
// ---------------------------------------------------------------------------

/// The human-readable keybinding label for [commandId] from the live keymap
/// (respecting user overrides), or null if unbound. Joins multi-chord
/// sequences with spaces.
String? keymapBindingLabel(KeymapService keymap, String commandId) {
  for (final b in keymap.effectiveBindings) {
    final i = b.intent;
    if (i is InvokeCommandIntent && i.commandId == commandId && b.sequence.isNotEmpty) {
      return b.sequence.map((c) => c.display).join(' ');
    }
  }
  return null;
}

/// Resolve the curated [tree] against the live command set into render-ready
/// menus. [bindingLabel] supplies the keybinding string for a command id
/// (typically [keymapBindingLabel] bound to the keymap); when it returns null
/// the command's own `defaultBinding` is used as a fallback.
List<ResolvedMenu> resolveMenus(
  List<TopMenu> tree,
  CommandRegistry registry,
  KernelServices services, {
  String? Function(String commandId)? bindingLabel,
}) {
  final placed = <String>{
    for (final m in tree)
      for (final n in m.nodes)
        if (n is MenuCommandItem) n.commandId,
  };

  String? label(String id) {
    final fromKeymap = bindingLabel?.call(id);
    if (fromKeymap != null) return fromKeymap;
    final db = registry.get(id)?.defaultBinding;
    if (db == null || db.isEmpty) return null;
    try {
      return KeyChord.parse(db).display;
    } catch (_) {
      return db;
    }
  }

  ResolvedItem resolveItem(MenuCommandItem item) {
    final cmd = registry.get(item.commandId);
    final enabled = cmd != null && (item.enabledWhen?.call(services) ?? true);
    final raw = cmd?.title ?? item.fallbackTitle ?? item.commandId;
    return ResolvedItem(commandId: item.commandId, title: _stripCategory(raw), enabled: enabled, keybinding: label(item.commandId));
  }

  List<ResolvedNode> expand(MenuNode n) => switch (n) {
        MenuCommandItem() => [resolveItem(n)],
        MenuSeparator() => const [ResolvedSeparator()],
        MenuAutoFill(:final prefix) => [
            for (final c in _autoFill(registry, prefix, placed)) resolveItem(MenuCommandItem(c.command)),
          ],
      };

  return [
    for (final m in tree) ResolvedMenu(title: m.title, mnemonic: m.mnemonic, items: [for (final n in m.nodes) ...expand(n)]),
  ];
}

List<CommandContribution> _autoFill(CommandRegistry registry, String prefix, Set<String> placed) {
  final hits = registry.all.where((c) => c.command.startsWith(prefix) && !placed.contains(c.command)).toList();
  hits.sort((a, b) => (a.title ?? a.command).toLowerCase().compareTo((b.title ?? b.command).toLowerCase()));
  return hits;
}

/// Strip a leading "Category: " prefix so "View: Zoom In" reads "Zoom In"
/// under the View menu. Only strips a single capitalised word + colon + space.
String _stripCategory(String title) {
  final m = RegExp(r'^[A-Z][A-Za-z]*:\s').firstMatch(title);
  return m == null ? title : title.substring(m.end);
}
