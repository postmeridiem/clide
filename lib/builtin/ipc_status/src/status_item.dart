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
    final cwd = Directory.current.path;
    final ptycResult = _exists('$cwd/native/linux-x64/ptyc') || _exists('$cwd/ptyc/bin/ptyc') || await _which('ptyc');
    final pqlResult = await _which('pql');
    if (!mounted) return;
    setState(() {
      _ptycOk = ptycResult;
      _pqlOk = pqlResult;
      _checked = true;
    });
  }

  bool _exists(String path) => File(path).existsSync();

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

    if (_ptycOk && _pqlOk) {
      return _chip('ok', tokens.statusSuccess, tokens);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_ptycOk) _chip('ptyc not found', tokens.statusWarning, tokens),
        if (!_ptycOk && !_pqlOk) const SizedBox(width: 10),
        if (!_pqlOk) _chip('pql not found', tokens.statusWarning, tokens),
      ],
    );
  }

  Widget _chip(String label, Color color, SurfaceTokens tokens) {
    return Semantics(
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            ClideText(label, fontSize: clideFontCaption, color: color),
          ],
        ),
      ),
    );
  }
}
