import 'dart:async';
import 'dart:io';

import 'package:clide/clide.dart' show FileEntry;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'file_tree_controller.dart';

/// Sidebar panel rendering the workspace file tree.
///
/// Lazy-expands directories via `files.ls`, subscribes to
/// `files.changed` events from the daemon, and refreshes the affected
/// subtrees on change. Click-to-open is plumbed through `kernel.commands`
/// — today the command doesn't exist yet (lands with Tier 2's editor);
/// the view degrades gracefully to a no-op when the command isn't
/// registered.
class FileTreeView extends StatefulWidget {
  const FileTreeView({super.key});

  @override
  State<FileTreeView> createState() => _FileTreeViewState();
}

class _FileTreeViewState extends State<FileTreeView> {
  FileTreeController? _controller;
  String _filter = '';
  final ScrollController _scroll = ScrollController();

  /// Key on the currently-selected row, so a keyboard move can scroll it into
  /// view (T-406).
  final GlobalKey _selectedKey = GlobalKey();

  /// Half-page step for ctrl+d / ctrl+u over the flattened tree.
  static const int _pageStep = 10;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = FileTreeController(ipc: kernel.ipc, events: kernel.events);
    unawaited(_controller!.load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onNav(NavIntent intent, int count, FileTreeController c) {
    switch (intent) {
      case NavDownIntent():
        c.moveSelection(count);
      case NavUpIntent():
        c.moveSelection(-count);
      case NavPageDownIntent():
        c.moveSelection(_pageStep);
      case NavPageUpIntent():
        c.moveSelection(-_pageStep);
      case NavTopIntent():
        c.selectEdge(top: true);
      case NavBottomIntent():
        c.selectEdge(top: false);
      case NavExpandOrRightIntent():
        unawaited(c.expandOrInto());
      case NavCollapseOrLeftIntent():
        unawaited(c.collapseOrOut());
      case NavActivateIntent():
        _activateSelected(c);
    }
  }

  void _activateSelected(FileTreeController c) {
    final t = c.activateTarget();
    if (t == null) return;
    if (t.isDirectory) {
      unawaited(c.toggle(t.path));
    } else {
      openWorkspaceFile(ClideKernel.of(context), t.path);
    }
  }

  /// Scroll the selected row into view after the frame it's laid out in.
  void _ensureSelectedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd, duration: const Duration(milliseconds: 80));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.error != null && c.rootPath == null) {
          return Padding(padding: const EdgeInsets.all(12), child: ClideText(c.error!, muted: true));
        }
        final root = c.rootPath;
        if (root == null) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: ClideText(ClideSettings.i18n.string(context, 'loading', namespace: 'builtin.files', placeholder: 'Loading…'), muted: true),
          );
        }
        final rootName = root.split(Platform.pathSeparator).last;
        final selected = c.selectedPath;
        if (_filter.isEmpty && selected != null) _ensureSelectedVisible();
        final scroller = SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_filter.isEmpty) ...[
                _DirRow(name: rootName, path: '', controller: c, depth: 0, selectedPath: selected, selectedKey: _selectedKey),
                if (c.isExpanded('')) _Children(path: '', controller: c, depth: 1, selectedPath: selected, selectedKey: _selectedKey),
              ] else
                ..._filteredEntries(c),
            ],
          ),
        );
        return Column(
          children: [
            ClideFilterBox(
              address: 'files.tree',
              hint: ClideSettings.i18n.string(context, 'filter.hint', namespace: 'builtin.files', placeholder: 'Filter files…'),
              onChanged: (v) => setState(() => _filter = v),
            ),
            Expanded(
              child: Semantics(
                label: ClideSettings.i18n.interpolated(
                  context,
                  'a11y.tree',
                  namespace: 'builtin.files',
                  placeholder: 'file tree — {name}',
                  replacers: [I18nReplacer(from: '{name}', replace: rootName)],
                ),
                container: true,
                explicitChildNodes: true,
                // Vim nav (j/k/h/l/gg/G/o) drives a selection cursor while this
                // region holds focus under the vim preset (T-406). The filter
                // box sits outside it, so typing a filter is never intercepted.
                child: _filter.isEmpty ? PaneKeyNav(onNav: (intent, count) => _onNav(intent, count, c), child: scroller) : scroller,
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _filteredEntries(FileTreeController c) {
    final lowerFilter = _filter.toLowerCase();
    final matches = c.allLoadedEntries().where((e) {
      return e.path.toLowerCase().contains(lowerFilter) || e.name.toLowerCase().contains(lowerFilter);
    }).toList();
    return [for (final e in matches) _FilteredFileRow(entry: e)];
  }
}

class _Children extends StatelessWidget {
  const _Children({required this.path, required this.controller, required this.depth, this.selectedPath, this.selectedKey});

  final String path;
  final FileTreeController controller;
  final int depth;
  final String? selectedPath;
  final Key? selectedKey;

  @override
  Widget build(BuildContext context) {
    final entries = controller.entriesFor(path);
    if (entries == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in entries)
          if (e.isDirectory)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DirRow(name: e.name, path: e.path, controller: controller, depth: depth, selectedPath: selectedPath, selectedKey: selectedKey),
                if (controller.isExpanded(e.path))
                  _Children(path: e.path, controller: controller, depth: depth + 1, selectedPath: selectedPath, selectedKey: selectedKey),
              ],
            )
          else
            _FileRow(name: e.name, path: e.path, depth: depth, selectedPath: selectedPath, selectedKey: selectedKey),
      ],
    );
  }
}

class _DirRow extends StatelessWidget {
  const _DirRow({required this.name, required this.path, required this.controller, required this.depth, this.selectedPath, this.selectedKey});

  final String name;
  final String path;
  final FileTreeController controller;
  final int depth;
  final String? selectedPath;
  final Key? selectedKey;

  @override
  Widget build(BuildContext context) {
    final expanded = controller.isExpanded(path);
    final tokens = ClideSettings.theme.of(context).surface;
    final selected = path == selectedPath;
    return Semantics(
      button: true,
      label: expanded
          ? ClideSettings.i18n.interpolated(
              context,
              'a11y.collapse',
              namespace: 'builtin.files',
              placeholder: 'Collapse {name}',
              replacers: [I18nReplacer(from: '{name}', replace: name)],
            )
          : ClideSettings.i18n.interpolated(
              context,
              'a11y.expand',
              namespace: 'builtin.files',
              placeholder: 'Expand {name}',
              replacers: [I18nReplacer(from: '{name}', replace: name)],
            ),
      onTap: () => controller.toggle(path),
      child: _Row(
        key: selected ? selectedKey : null,
        depth: depth,
        onTap: () => controller.toggle(path),
        leading: ClideIcon(const ChevronRightIcon(), size: 10, color: tokens.sidebarForeground),
        label: name,
        rotateLeading: expanded,
        selected: selected,
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.name, required this.path, required this.depth, this.selectedPath, this.selectedKey});

  final String name;
  final String path;
  final int depth;
  final String? selectedPath;
  final Key? selectedKey;

  @override
  Widget build(BuildContext context) {
    final selected = path == selectedPath;
    return Semantics(
      button: true,
      label: ClideSettings.i18n.interpolated(
        context,
        'a11y.open',
        namespace: 'builtin.files',
        placeholder: 'Open {name}',
        replacers: [I18nReplacer(from: '{name}', replace: name)],
      ),
      onTap: () => _openFile(context, path),
      child: _Row(key: selected ? selectedKey : null, depth: depth, onTap: () => _openFile(context, path), label: name, selected: selected),
    );
  }

  void _openFile(BuildContext context, String path) {
    // Shared routing (T-187): .md → markdown reader, else editor.open;
    // records the open in RecentFilesService for quick-open (T-51).
    openWorkspaceFile(ClideKernel.of(context), path);
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.depth, required this.onTap, required this.label, this.leading, this.rotateLeading = false, this.selected = false});

  final int depth;
  final VoidCallback onTap;
  final String label;
  final Widget? leading;
  final bool rotateLeading;

  /// True when the keyboard selection cursor is on this row (T-406) — draws a
  /// persistent highlight + accent ring, distinct from transient hover.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final leftPadding = 8.0 + (depth * 14.0);
    return ClideTappable(
      onTap: onTap,
      builder: (context, hovered, _) => Container(
        decoration: selected
            ? BoxDecoration(
                color: tokens.sidebarItemHover,
                border: Border.all(color: tokens.globalFocus, width: 1),
              )
            : (hovered ? BoxDecoration(color: tokens.sidebarItemHover) : null),
        padding: EdgeInsets.only(left: leftPadding, right: 8, top: 3, bottom: 3),
        child: Row(
          children: [
            if (leading != null) ...[
              Transform.rotate(
                angle: rotateLeading ? 1.5708 : 0, // 90° when expanded
                child: leading,
              ),
              const SizedBox(width: 6),
            ] else
              const SizedBox(width: 16),
            Expanded(
              child: ClideText(label, maxLines: 1, overflow: TextOverflow.ellipsis, color: tokens.sidebarForeground),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredFileRow extends StatelessWidget {
  const _FilteredFileRow({required this.entry});
  final FileEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return ClideTappable(
      onTap: () => openWorkspaceFile(ClideKernel.of(context), entry.path),
      builder: (context, hovered, _) => Container(
        color: hovered ? tokens.sidebarItemHover : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: ClideText(entry.path, maxLines: 1, overflow: TextOverflow.ellipsis, color: tokens.sidebarForeground),
      ),
    );
  }
}
