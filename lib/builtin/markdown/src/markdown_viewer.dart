import 'dart:async';

import 'package:clide/builtin/shared/reader_chrome.dart';
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
  ReaderNav? _nav;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectionSub != null) return;
    final kernel = ClideKernel.of(context);
    // Back/forward history is the retained right-pane nav (T-196); it
    // records selections and re-emits them on the 'load' channel.
    _nav = kernel.readerNav.navFor('builtin.markdown', dataKey: 'path')..addListener(_onNavChanged);
    _selectionSub = kernel.messages.subscribe(publisher: 'builtin.markdown', channel: 'load').listen((msg) {
      final path = msg.data['path'] as String?;
      if (path != null) _loadFile(path);
    });
    // Grab the latest entry the nav already holds (a selection that
    // revealed this tab before we subscribed).
    final current = _nav!.current;
    if (current != null) _loadFile(current);
  }

  void _onNavChanged() {
    if (mounted) setState(() {}); // refresh action-bar button state
  }

  @override
  void dispose() {
    _selectionSub?.cancel();
    _nav?.removeListener(_onNavChanged);
    super.dispose();
  }

  /// Fetch + display [path]. History lives in [ReaderNav]; never pushes.
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

  void _onBack() => _nav?.back();
  void _onForward() => _nav?.forward();
  void _onPin() => _nav?.pin();
  void _onJumpToPin() => _nav?.jumpToPin();

  void _onEdit() {
    final p = _path;
    if (p == null) return;
    final kernel = ClideKernel.of(context);
    unawaited(kernel.ipc.request('editor.open', args: {'path': p}));
  }

  void _navigateToRecord(BuildContext context, String id) {
    final kernel = ClideKernel.of(context);
    if (id.toLowerCase().endsWith('.md')) {
      // Wiki-link to another .md file — open it in the reader.
      kernel.messages.publish('builtin.markdown', 'selection', {'path': id});
    } else if (id.startsWith('T-')) {
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
      trailing: [
        ReaderActionBar(
          canGoBack: _nav?.canGoBack ?? false,
          canGoForward: _nav?.canGoForward ?? false,
          hasPinned: _nav?.hasPinned ?? false,
          onBack: (_nav?.canGoBack ?? false) ? _onBack : null,
          onForward: (_nav?.canGoForward ?? false) ? _onForward : null,
          onPin: _path != null ? _onPin : null,
          onJumpToPin: (_nav?.hasPinned ?? false) ? _onJumpToPin : null,
          onEdit: _path != null ? _onEdit : null,
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: ClideMarkdown(_content!, onRecordTap: (id) => _navigateToRecord(context, id)),
      ),
    );
  }
}
