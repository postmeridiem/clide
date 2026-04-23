import 'dart:async';
import 'dart:convert';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class GraphView extends StatefulWidget {
  const GraphView({super.key});

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> {
  List<_GraphNode> _nodes = [];
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading || _nodes.isNotEmpty) return;
    unawaited(_load());
  }

  Future<void> _load() async {
    final kernel = ClideKernel.of(context);
    final resp = await kernel.ipc.request('pql.exec', args: {
      'argv': ['search', '--connections', '--limit', '50'],
    });
    if (!mounted) return;
    if (!resp.ok) {
      setState(() {
        _error = resp.error?.message ?? 'failed to load graph';
        _loading = false;
      });
      return;
    }
    final raw = resp.data['stdout'] as String? ?? '[]';
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      setState(() {
        _nodes = list.map(_GraphNode.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'parse error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    if (_loading) {
      return const Center(child: ClideText('Loading graph...', muted: true));
    }
    if (_error != null) {
      return Padding(padding: const EdgeInsets.all(12), child: ClideText(_error!, muted: true));
    }
    if (_nodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: ClideText('No linked files found.\nAdd wikilinks to your markdown files.', muted: true),
      );
    }
    return ListView.builder(
      itemCount: _nodes.length,
      itemBuilder: (ctx, i) {
        final n = _nodes[i];
        return _NodeRow(node: n, tokens: tokens);
      },
    );
  }
}

class _GraphNode {
  const _GraphNode({required this.path, this.inbound = 0, this.outbound = 0});
  final String path;
  final int inbound;
  final int outbound;

  factory _GraphNode.fromJson(Map<String, dynamic> json) => _GraphNode(
        path: json['path'] as String? ?? json['relative_path'] as String? ?? '',
        inbound: (json['inbound_count'] as num?)?.toInt() ?? 0,
        outbound: (json['outbound_count'] as num?)?.toInt() ?? 0,
      );
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.node, required this.tokens});
  final _GraphNode node;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ClideTappable(
      builder: (context, hovered, _) => Container(
        color: hovered ? tokens.listItemHoverBackground : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(child: ClideText(node.path, fontSize: 13)),
            ClideText('${node.inbound}in ${node.outbound}out', color: tokens.globalTextMuted, fontSize: 11),
          ],
        ),
      ),
    );
  }
}
