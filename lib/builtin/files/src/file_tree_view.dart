import 'dart:async';
import 'dart:io';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'package:clide/src/files/listing.dart' show FileEntry;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.error != null && c.rootPath == null) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: ClideText(c.error!, muted: true),
          );
        }
        final root = c.rootPath;
        if (root == null) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: ClideText('Loading…', muted: true),
          );
        }
        final rootName = root.split(Platform.pathSeparator).last;
        return Column(
          children: [
            ClideFilterBox(hint: 'Filter files…', onChanged: (v) => setState(() => _filter = v)),
            Expanded(
              child: Semantics(
                label: 'file tree — $rootName',
                container: true,
                explicitChildNodes: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_filter.isEmpty) ...[
                        _DirRow(name: rootName, path: '', controller: c, depth: 0),
                        if (c.isExpanded('')) _Children(path: '', controller: c, depth: 1),
                      ] else
                        ..._filteredEntries(c),
                    ],
                  ),
                ),
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
    return [
      for (final e in matches) _FilteredFileRow(entry: e),
    ];
  }
}

class _Children extends StatelessWidget {
  const _Children({
    required this.path,
    required this.controller,
    required this.depth,
  });

  final String path;
  final FileTreeController controller;
  final int depth;

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
                _DirRow(
                  name: e.name,
                  path: e.path,
                  controller: controller,
                  depth: depth,
                ),
                if (controller.isExpanded(e.path))
                  _Children(path: e.path, controller: controller, depth: depth + 1),
              ],
            )
          else
            _FileRow(
              name: e.name,
              path: e.path,
              depth: depth,
            ),
      ],
    );
  }
}

class _DirRow extends StatelessWidget {
  const _DirRow({
    required this.name,
    required this.path,
    required this.controller,
    required this.depth,
  });

  final String name;
  final String path;
  final FileTreeController controller;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final expanded = controller.isExpanded(path);
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      button: true,
      label: '${expanded ? 'Collapse' : 'Expand'} $name',
      onTap: () => controller.toggle(path),
      child: _Row(
        depth: depth,
        onTap: () => controller.toggle(path),
        leading: ClideIcon(
          const ChevronRightIcon(),
          size: 10,
          color: tokens.sidebarForeground,
        ),
        label: name,
        rotateLeading: expanded,
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.name,
    required this.path,
    required this.depth,
  });

  final String name;
  final String path;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open $name',
      onTap: () => _openFile(context, path),
      child: _Row(
        depth: depth,
        onTap: () => _openFile(context, path),
        label: name,
      ),
    );
  }

  void _openFile(BuildContext context, String path) {
    final kernel = ClideKernel.of(context);
    // editor.open is a daemon-side IPC handler (lib/src/daemon/
    // editor_commands.dart), not a kernel command. Fire the request
    // and let the editor extension's controller pick up the
    // editor.active-changed / editor.opened event — no need to await
    // or handle the response here.
    unawaited(
      kernel.ipc.request('editor.open', args: {'path': path}),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.depth,
    required this.onTap,
    required this.label,
    this.leading,
    this.rotateLeading = false,
  });

  final int depth;
  final VoidCallback onTap;
  final String label;
  final Widget? leading;
  final bool rotateLeading;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final leftPadding = 8.0 + (widget.depth * 14.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: _hover ? tokens.sidebarItemHover : null,
          padding: EdgeInsets.only(left: leftPadding, right: 8, top: 3, bottom: 3),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                Transform.rotate(
                  angle: widget.rotateLeading ? 1.5708 : 0, // 90° when expanded
                  child: widget.leading,
                ),
                const SizedBox(width: 6),
              ] else
                const SizedBox(width: 16),
              Expanded(
                child: ClideText(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  color: tokens.sidebarForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilteredFileRow extends StatefulWidget {
  const _FilteredFileRow({required this.entry});
  final FileEntry entry;

  @override
  State<_FilteredFileRow> createState() => _FilteredFileRowState();
}

class _FilteredFileRowState extends State<_FilteredFileRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final kernel = ClideKernel.of(context);
          unawaited(kernel.ipc.request('editor.open', args: {'path': widget.entry.path}));
        },
        child: Container(
          color: _hover ? tokens.sidebarItemHover : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: ClideText(widget.entry.path, maxLines: 1, overflow: TextOverflow.ellipsis, color: tokens.sidebarForeground),
        ),
      ),
    );
  }
}

