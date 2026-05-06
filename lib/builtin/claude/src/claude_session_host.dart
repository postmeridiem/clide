import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'claude_pane.dart';

/// Hosts the primary Claude pane plus N user-spawned secondary
/// sessions per D-41. Uses [MultitabPane] for the tab strip
/// (drag-reorder, close ×, + button) and [IndexedStack]-mode
/// keep-alive so switching tabs doesn't tear down the underlying
/// PTY-backed terminal.
class ClaudeSessionHost extends StatefulWidget {
  const ClaudeSessionHost({super.key});

  @override
  State<ClaudeSessionHost> createState() => ClaudeSessionHostState();
}

class ClaudeSessionHostState extends State<ClaudeSessionHost> {
  static const _primaryId = 'primary';

  late final MultitabController<_Session> _controller;
  int _nextSecondary = 1;

  @override
  void initState() {
    super.initState();
    _controller = MultitabController<_Session>(
      initial: [
        MultitabEntry<_Session>(
          id: _primaryId,
          title: 'primary',
          payload: const _Session(isPrimary: true),
          // Primary persists across clide restarts and never gets a
          // close affordance (D-41).
          closeable: false,
          reorderable: false,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Public entry point used by the `claude.new-secondary` command.
  void addSecondary() {
    final index = _nextSecondary++;
    _controller.add(MultitabEntry<_Session>(
      id: 'secondary-$index',
      title: 'session $index',
      payload: _Session(isPrimary: false, secondaryIndex: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MultitabPane<_Session>(
      controller: _controller,
      keepAlive: true,
      onAddRequested: addSecondary,
      bodyBuilder: (ctx, entry) {
        final s = entry.payload;
        return ClaudePane(
          isPrimary: s.isPrimary,
          secondaryIndex: s.secondaryIndex,
          // The MultitabPane already provides the tab strip header;
          // suppressing the ClaudePane's own chrome avoids a double row.
          showChrome: false,
        );
      },
    );
  }
}

class _Session {
  const _Session({required this.isPrimary, this.secondaryIndex});
  final bool isPrimary;
  final int? secondaryIndex;
}
