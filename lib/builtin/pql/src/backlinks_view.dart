/// Context panel showing backlinks and outlinks for the active file.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
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
        final tokens = ClideSettings.theme.of(context).surface;
        if (c.activePath == null) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: ClideText(
              ClideSettings.i18n.string(context, 'backlinks.empty', namespace: 'builtin.pql', placeholder: 'Open a file to see its links.'),
              muted: true,
            ),
          );
        }
        return Semantics(
          label: ClideSettings.i18n.interpolated(
            context,
            'backlinks.semantics',
            namespace: 'builtin.pql',
            placeholder: 'backlinks for {path}',
            replacers: [I18nReplacer(from: '{path}', replace: c.activePath!)],
          ),
          container: true,
          explicitChildNodes: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ClideText(c.activePath!.split('/').last, color: tokens.globalForeground),
                ),
                if (c.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ClideText(c.error!, color: tokens.statusError, fontSize: clideFontCaption),
                  ),
                if (c.loading)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClideText(ClideSettings.i18n.string(context, 'backlinks.loading', namespace: 'builtin.pql', placeholder: 'Loading…'), muted: true),
                  ),
                _LinkGroup(
                  label: ClideSettings.i18n.string(context, 'group.backlinks', namespace: 'builtin.pql', placeholder: 'Backlinks'),
                  links: c.backlinks,
                  pathKey: 'source',
                ),
                _LinkGroup(
                  label: ClideSettings.i18n.string(context, 'group.outlinks', namespace: 'builtin.pql', placeholder: 'Outlinks'),
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
  const _LinkGroup({required this.label, required this.links, required this.pathKey});

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
          padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 2),
          child: ClideText(
            ClideSettings.i18n.interpolated(
              context,
              'group.label',
              namespace: 'builtin.pql',
              placeholder: '{label} ({count})',
              replacers: [
                I18nReplacer(from: '{label}', replace: label),
                I18nReplacer(from: '{count}', replace: '${links.length}'),
              ],
            ),
            fontSize: clideFontCaption,
            muted: true,
          ),
        ),
        if (links.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            child: ClideText(
              ClideSettings.i18n.string(context, 'group.none', namespace: 'builtin.pql', placeholder: 'None'),
              fontSize: clideFontCaption,
              muted: true,
            ),
          ),
        for (final link in links) _LinkRow(link: link, pathKey: pathKey),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.pathKey});
  final Map<String, Object?> link;
  final String pathKey;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final target = link[pathKey] as String? ?? '';
    final alias = link['alias'] as String?;
    final display = alias ?? target;

    return Semantics(
      button: true,
      label: target,
      child: ClideTappable(
        onTap: () {
          if (!target.startsWith('http')) {
            final kernel = ClideKernel.of(context);
            unawaited(kernel.ipc.request('editor.open', args: {'path': target}));
          }
        },
        builder: (context, hovered, _) => Container(
          color: hovered ? tokens.sidebarItemHover : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: ClideText(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            color: target.startsWith('http') ? tokens.statusInfo : tokens.sidebarForeground,
          ),
        ),
      ),
    );
  }
}
