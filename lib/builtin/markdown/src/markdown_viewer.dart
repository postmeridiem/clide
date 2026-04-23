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
  StreamSubscription<Message>? _selectionSub;
  StreamSubscription<DaemonEvent>? _editorSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectionSub != null) return;
    final kernel = ClideKernel.of(context);
    _selectionSub = kernel.messages.subscribe(publisher: 'builtin.markdown', channel: 'load').listen((msg) {
      final path = msg.data['path'] as String?;
      if (path != null) _loadFile(path);
    });
    _editorSub = kernel.events.on<DaemonEvent>().listen((e) {
      if (e.kind == 'editor.buffer_activated') {
        final path = e.data['path'] as String?;
        if (path != null && path.endsWith('.md')) {
          _loadFile(path);
        }
      }
    });
  }

  @override
  void dispose() {
    _selectionSub?.cancel();
    _editorSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFile(String path) async {
    final kernel = ClideKernel.of(context);
    final resp = await kernel.ipc.request('files.read', args: {'path': path});
    if (!mounted) return;
    if (resp.ok) {
      kernel.messages.publish('builtin.markdown', 'focus', {'path': path});
      setState(() {
        _path = path;
        _content = resp.data['content'] as String? ?? '';
        _error = null;
      });
    } else {
      setState(() => _error = resp.error?.message);
    }
  }

  void _navigateToRecord(BuildContext context, String id) {
    final kernel = ClideKernel.of(context);
    if (id.startsWith('T-')) {
      kernel.messages.publish('builtin.tickets', 'selection', {'id': id});
    } else {
      kernel.messages.publish('builtin.decisions', 'selection', {'id': id});
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
        child: ClideText('Select a .md file to preview it here.', muted: true),
      );
    }
    return ClidePaneChrome(
      title: _path ?? 'viewer',
      subtitle: '${_content!.split('\n').length} lines',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: ClideMarkdown(_content!, onRecordTap: (id) => _navigateToRecord(context, id)),
      ),
    );
  }
}
