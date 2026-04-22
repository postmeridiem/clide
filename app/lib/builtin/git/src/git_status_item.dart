import 'dart:async';

import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class GitStatusItem extends StatefulWidget {
  const GitStatusItem({super.key});

  @override
  State<GitStatusItem> createState() => _GitStatusItemState();
}

class _GitStatusItemState extends State<GitStatusItem> {
  String? _branch;
  int _ahead = 0;
  int _behind = 0;
  StreamSubscription<DaemonEvent>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub != null) return;
    final kernel = ClideKernel.of(context);
    _sub = kernel.events.on<DaemonEvent>().listen(_onEvent);
    unawaited(_load(kernel.ipc));
  }

  Future<void> _load(DaemonClient ipc) async {
    final r = await ipc.request('git.status');
    if (!r.ok || !mounted) return;
    setState(() {
      _branch = r.data['branch'] as String?;
      _ahead = (r.data['ahead'] as num?)?.toInt() ?? 0;
      _behind = (r.data['behind'] as num?)?.toInt() ?? 0;
    });
  }

  void _onEvent(DaemonEvent e) {
    if (e.subsystem != 'git' || e.kind != 'git.changed') return;
    final kernel = ClideKernel.of(context);
    unawaited(_load(kernel.ipc));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _openBranchPicker() {
    final kernel = ClideKernel.of(context);
    kernel.dialog.show<String>(
      (ctx, dismiss) => _BranchPicker(
        ipc: kernel.ipc,
        currentBranch: _branch,
        onDismiss: dismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    if (_branch == null) return const SizedBox.shrink();
    final parts = <String>[_branch!];
    if (_ahead > 0) parts.add('↑$_ahead');
    if (_behind > 0) parts.add('↓$_behind');
    return Semantics(
      button: true,
      label: 'switch branch — $_branch',
      child: GestureDetector(
        onTap: _openBranchPicker,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClideIcon(
                  const GitBranchIcon(),
                  size: 12,
                  color: tokens.statusBarForeground,
                ),
                const SizedBox(width: 4),
                ClideText(
                  parts.join(' '),
                  fontSize: clideFontCaption,
                  color: tokens.statusBarForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BranchPicker extends StatefulWidget {
  const _BranchPicker({
    required this.ipc,
    required this.currentBranch,
    required this.onDismiss,
  });

  final DaemonClient ipc;
  final String? currentBranch;
  final void Function([String?]) onDismiss;

  @override
  State<_BranchPicker> createState() => _BranchPickerState();
}

class _BranchPickerState extends State<_BranchPicker> {
  List<Map<String, Object?>> _branches = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final r = await widget.ipc.request('git.branches');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _branches = [
          for (final b in (r.data['branches'] as List? ?? const []))
            (b as Map).cast<String, Object?>(),
        ];
      }
    });
  }

  Future<void> _checkout(String branch) async {
    await widget.ipc.request('git.checkout', args: {'branch': branch});
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      width: 320,
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: tokens.dropdownBackground,
        border: Border.all(color: tokens.dropdownBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ClideText(
              'Switch branch',
              fontSize: clideFontCaption,
              color: tokens.globalTextMuted,
              fontFamily: clideMonoFamily,
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: ClideText('Loading…', muted: true),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _branches.length,
              itemBuilder: (ctx, i) {
                final b = _branches[i];
                final name = b['name'] as String? ?? '';
                final current = b['current'] as bool? ?? false;
                return _BranchRow(
                  name: name,
                  current: current,
                  onTap: current ? null : () => unawaited(_checkout(name)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchRow extends StatefulWidget {
  const _BranchRow({
    required this.name,
    required this.current,
    this.onTap,
  });

  final String name;
  final bool current;
  final VoidCallback? onTap;

  @override
  State<_BranchRow> createState() => _BranchRowState();
}

class _BranchRowState extends State<_BranchRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return MouseRegion(
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hover ? tokens.listItemHoverBackground : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              if (widget.current)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClideIcon(
                    const CheckIcon(),
                    size: 12,
                    color: tokens.statusSuccess,
                  ),
                )
              else
                const SizedBox(width: 20),
              Expanded(
                child: ClideText(
                  widget.name,
                  fontFamily: clideMonoFamily,
                  fontSize: clideFontMono,
                  color: widget.current
                      ? tokens.globalForeground
                      : tokens.listItemForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
