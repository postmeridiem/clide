import 'dart:async';

import 'package:clide/builtin/shared/reader_chrome.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Whether [path] is a markdown file the reader can mirror live (T-36, D-50).
/// Non-renderable files get no auto-viewer (D-50 behavior 5).
bool isRenderableMarkdownPath(String path) {
  final p = path.toLowerCase();
  return p.endsWith('.md') || p.endsWith('.markdown');
}

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
  ReaderNav? _nav;

  /// Live-sync mirror state (T-36, D-50 behavior 4): when [_mirror] is true the
  /// view is a read-only reflection of the open editor buffer [_mirrorId] and
  /// re-reads it on every edit, rather than a disk snapshot.
  bool _mirror = false;
  String? _mirrorId;

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
    // Live-sync: mirror the editor buffer as it's typed (T-36).
    _editorSub = kernel.events.on<DaemonEvent>().listen(_onEditorEvent);
    // The editor may have opened before this viewer mounted (the extension
    // reveals the tab on editor.opened) — pick up the active buffer now.
    unawaited(_mirrorActiveIfRenderable(kernel));
    // Grab the latest entry the nav already holds (a selection that
    // revealed this tab before we subscribed).
    final current = _nav!.current;
    if (current != null) _loadFile(current);
  }

  /// On mount, mirror the active editor buffer if it's a renderable file —
  /// `editor.read` with no id resolves to the active buffer.
  Future<void> _mirrorActiveIfRenderable(KernelServices kernel) async {
    final resp = await kernel.ipc.request('editor.read', args: const {});
    if (!mounted || !resp.ok) return;
    final path = resp.data['path'] as String?;
    final id = resp.data['id'] as String?;
    if (path != null && id != null && isRenderableMarkdownPath(path)) {
      _enterMirror(id, path, resp.data['content'] as String? ?? '');
    }
  }

  void _onEditorEvent(DaemonEvent e) {
    if (e.subsystem != 'editor') return;
    final id = e.data['id'] as String?;
    final path = e.data['path'] as String?;
    switch (e.kind) {
      case 'editor.opened':
        if (id != null && path != null && isRenderableMarkdownPath(path)) _enterMirror(id, path, e.data['content'] as String? ?? '');
      case 'editor.active-changed':
        // Followed the active buffer: mirror a renderable one, drop the mirror
        // for a non-renderable / no buffer (D-50 behavior 5 — no auto-viewer).
        if (id != null && path != null && isRenderableMarkdownPath(path)) {
          unawaited(_reread(id, path));
        } else {
          if (_mirror) setState(() => _mirror = false);
        }
      case 'editor.edited':
        if (_mirror && id != null && id == _mirrorId && _path != null) unawaited(_reread(id, _path!));
      case 'editor.closed':
        if (id == _mirrorId && _mirror) setState(() => _mirror = false);
    }
  }

  /// Re-read the in-memory buffer [id] and refresh the mirror (live edits).
  Future<void> _reread(String id, String path) async {
    final resp = await ClideKernel.of(context).ipc.request('editor.read', args: {'id': id});
    if (!mounted || !resp.ok) return;
    _enterMirror(id, path, resp.data['content'] as String? ?? '');
  }

  void _enterMirror(String id, String path, String content) {
    setState(() {
      _mirror = true;
      _mirrorId = id;
      _path = path;
      _content = content;
      _error = null;
    });
  }

  void _onNavChanged() {
    if (mounted) setState(() {}); // refresh action-bar button state
  }

  @override
  void dispose() {
    _selectionSub?.cancel();
    _editorSub?.cancel();
    _nav?.removeListener(_onNavChanged);
    super.dispose();
  }

  /// Fetch + display [path] from disk. An explicit (agent-driven) selection, so
  /// it leaves mirror mode — the edit affordance returns. History lives in
  /// [ReaderNav]; never pushes.
  Future<void> _loadFile(String path) async {
    final kernel = ClideKernel.of(context);
    final resp = await kernel.ipc.request('files.read', args: {'path': path});
    if (!mounted) return;
    if (resp.ok) {
      kernel.messages.publish('builtin.markdown', 'focus', {'path': path});
      setState(() {
        _mirror = false;
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
  void _onPin() => _nav?.togglePin();
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
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ClideText(
          ClideSettings.i18n.string(context, 'empty', namespace: 'builtin.markdown', placeholder: 'Select a .md file to preview it here.'),
          muted: true,
        ),
      );
    }
    return ClidePaneChrome(
      title: _path ?? ClideSettings.i18n.string(context, 'chrome.title', namespace: 'builtin.markdown', placeholder: 'viewer'),
      subtitle: ClideSettings.i18n.interpolated(
        context,
        'subtitle.lines',
        namespace: 'builtin.markdown',
        placeholder: '{count} lines',
        replacers: [I18nReplacer(from: '{count}', replace: '${_content!.split('\n').length}')],
      ),
      leading: ReaderPinButton(pinned: _nav?.hasPinned ?? false, onTap: _path != null ? _onPin : null),
      trailing: [
        ReaderActionBar(
          canGoBack: _nav?.canGoBack ?? false,
          canGoForward: _nav?.canGoForward ?? false,
          hasPinned: _nav?.hasPinned ?? false,
          onBack: (_nav?.canGoBack ?? false) ? _onBack : null,
          onForward: (_nav?.canGoForward ?? false) ? _onForward : null,
          onJumpToPin: (_nav?.hasPinned ?? false) ? _onJumpToPin : null,
          // Read-only while mirroring the live buffer (T-36): the file is already
          // open in the editor, so no edit affordance here.
          onEdit: (!_mirror && _path != null) ? _onEdit : null,
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: ClideMarkdown(_content!, onRecordTap: (id) => _navigateToRecord(context, id)),
      ),
    );
  }
}
