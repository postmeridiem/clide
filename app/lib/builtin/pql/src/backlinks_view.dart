/// Context panel showing backlinks and outlinks for the active file.
library;

import 'dart:async';

import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'backlinks_controller.dart';

class BacklinksView extends StatefulWidget {
  const BacklinksView({super.key});

  @override
  State<BacklinksView> createState() => _BacklinksViewState();
}

class _BacklinksViewState extends State<BacklinksView> {
  BacklinksController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = BacklinksController(ipc: kernel.ipc, events: kernel.events);
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
        final tokens = ClideTheme.of(context).surface;
        if (c.activePath == null) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: ClideText(
              'Open a file to see its links.',
              muted: true,
            ),
          );
        }
        return Semantics(
          label: 'backlinks for ${c.activePath}',
          container: true,
          explicitChildNodes: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: ClideText(
                    c.activePath!.split('/').last,
                    color: tokens.globalForeground,
                  ),
                ),
                if (c.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: ClideText(
                      c.error!,
                      color: tokens.statusError,
                      fontSize: clideFontCaption,
                    ),
                  ),
                if (c.loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: ClideText('Loading…', muted: true),
                  ),
                _LinkGroup(
                  label: 'Backlinks',
                  links: c.backlinks,
                  pathKey: 'source',
                ),
                _LinkGroup(
                  label: 'Outlinks',
                  links: c.outlinks,
                  pathKey: 'target',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LinkGroup extends StatelessWidget {
  const _LinkGroup({
    required this.label,
    required this.links,
    required this.pathKey,
  });

  final String label;
  final List<Map<String, Object?>> links;
  final String pathKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 2),
          child: ClideText(
            '$label (${links.length})',
            fontSize: clideFontCaption,
            muted: true,
          ),
        ),
        if (links.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            child: ClideText('None', fontSize: clideFontCaption, muted: true),
          ),
        for (final link in links)
          _LinkRow(link: link, pathKey: pathKey),
      ],
    );
  }
}

class _LinkRow extends StatefulWidget {
  const _LinkRow({required this.link, required this.pathKey});
  final Map<String, Object?> link;
  final String pathKey;

  @override
  State<_LinkRow> createState() => _LinkRowState();
}

class _LinkRowState extends State<_LinkRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final target = widget.link[widget.pathKey] as String? ?? '';
    final alias = widget.link['alias'] as String?;
    final display = alias ?? target;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!target.startsWith('http')) {
            final kernel = ClideKernel.of(context);
            unawaited(
                kernel.ipc.request('editor.open', args: {'path': target}));
          }
        },
        child: Semantics(
          button: true,
          label: target,
          child: Container(
            color: _hover ? tokens.sidebarItemHover : null,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            child: ClideText(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              color: target.startsWith('http')
                  ? tokens.statusInfo
                  : tokens.sidebarForeground,
            ),
          ),
        ),
      ),
    );
  }
}
