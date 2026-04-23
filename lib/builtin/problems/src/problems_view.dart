/// Sidebar panel showing project diagnostics from pql.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'problems_controller.dart';

class ProblemsView extends StatefulWidget {
  const ProblemsView({super.key});

  @override
  State<ProblemsView> createState() => _ProblemsViewState();
}

class _ProblemsViewState extends State<ProblemsView> {
  ProblemsController? _controller;
  String _filter = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final kernel = ClideKernel.of(context);
    _controller = ProblemsController(ipc: kernel.ipc);
    unawaited(_controller!.refresh());
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
        return Semantics(
          label: 'problems panel',
          container: true,
          explicitChildNodes: true,
          child: () {
            final lf = _filter.toLowerCase();
            final filtered = lf.isEmpty ? c.problems : c.problems.where((p) => p.message.toLowerCase().contains(lf) || p.source.toLowerCase().contains(lf)).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClideFilterBox(hint: 'Filter problems…', onChanged: (v) => setState(() => _filter = v)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: ClideText('Problems (${filtered.length})', fontSize: clideFontCaption, color: tokens.sidebarForeground)),
                      Semantics(
                        button: true,
                        label: 'refresh problems',
                        child: GestureDetector(
                          onTap: () => unawaited(c.refresh()),
                          child: MouseRegion(cursor: SystemMouseCursors.click, child: ClideText('Refresh', fontSize: clideFontCaption, color: tokens.sidebarForeground)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (c.loading && c.problems.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: ClideText('Scanning…', muted: true)),
                if (!c.loading && filtered.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: ClideText('No problems found.', muted: true)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [for (final p in filtered) _ProblemRow(problem: p)],
                    ),
                  ),
                ),
              ],
            );
          }(),
        );
      },
    );
  }
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({required this.problem});
  final Problem problem;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClideText(
                problem.source,
                fontSize: clideFontMono,
                color: tokens.statusWarning,
                fontFamily: clideMonoFamily,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClideText(
                  problem.message,
                  color: tokens.sidebarForeground,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          if (problem.hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 2),
              child: ClideText(
                problem.hint!,
                fontSize: clideFontMono,
                muted: true,
                fontFamily: clideMonoFamily,
              ),
            ),
        ],
      ),
    );
  }
}
