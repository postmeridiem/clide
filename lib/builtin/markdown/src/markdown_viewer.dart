import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class MarkdownViewer extends StatefulWidget {
  const MarkdownViewer({super.key});

  @override
  State<MarkdownViewer> createState() => _MarkdownViewerState();
}

class _MarkdownViewerState extends State<MarkdownViewer> {
  String? _path;
  String? _content;
  String? _error;
  StreamSubscription<DaemonEvent>? _eventSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_eventSub != null) return;
    final kernel = ClideKernel.of(context);
    _eventSub = kernel.events.on<DaemonEvent>().listen((e) {
      if (e.kind == 'editor.buffer_activated') {
        final path = e.data['path'] as String?;
        if (path != null && path.endsWith('.md')) {
          _loadFile(path);
        }
      }
    });
    final activeTab = kernel.panels.activeTabIn(Slots.workspace);
    if (activeTab == 'editor.active') {
      unawaited(_loadActiveBuffer());
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveBuffer() async {
    final kernel = ClideKernel.of(context);
    final resp = await kernel.ipc.request('editor.active');
    if (!mounted || !resp.ok) return;
    final path = resp.data['path'] as String?;
    if (path != null && path.endsWith('.md')) {
      await _loadFile(path);
    }
  }

  Future<void> _loadFile(String path) async {
    final kernel = ClideKernel.of(context);
    final resp = await kernel.ipc.request('files.read', args: {'path': path});
    if (!mounted) return;
    if (resp.ok) {
      setState(() {
        _path = path;
        _content = resp.data['content'] as String? ?? '';
        _error = null;
      });
    } else {
      setState(() => _error = resp.error?.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(padding: const EdgeInsets.all(12), child: ClideText(_error!, muted: true));
    }
    if (_content == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: ClideText('Open a .md file to preview it here.', muted: true),
      );
    }
    return ClidePaneChrome(
      title: _path ?? 'viewer',
      subtitle: '${_content!.split('\n').length} lines',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: ClideMarkdown(_content!),
      ),
    );
  }
}
