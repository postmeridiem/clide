import 'dart:io';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ToolStatusItem extends StatefulWidget {
  const ToolStatusItem({super.key});

  @override
  State<ToolStatusItem> createState() => _ToolStatusItemState();
}

class _ToolStatusItemState extends State<ToolStatusItem> {
  bool _ptycOk = false;
  bool _pqlOk = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ptycResult = await _which('ptyc');
    final pqlResult = await _which('pql');
    if (!mounted) return;
    setState(() {
      _ptycOk = ptycResult;
      _pqlOk = pqlResult;
      _checked = true;
    });
  }

  Future<bool> _which(String name) async {
    try {
      final r = await Process.run('which', [name]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    if (!_checked) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Indicator(label: 'ptyc', ok: _ptycOk, tokens: tokens),
          const SizedBox(width: 10),
          _Indicator(label: 'pql', ok: _pqlOk, tokens: tokens),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.label, required this.ok, required this.tokens});
  final String label;
  final bool ok;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final color = ok ? tokens.statusSuccess : tokens.statusWarning;
    return Semantics(
      label: '$label ${ok ? "available" : "not found"}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClideIcon(PhosphorIcons.circlesFour, size: 10, color: color),
          const SizedBox(width: 4),
          ClideText(label, fontSize: clideFontCaption, color: color, fontFamily: clideMonoFamily),
        ],
      ),
    );
  }
}
