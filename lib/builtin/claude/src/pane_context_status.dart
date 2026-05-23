/// The status-bar "in-pane context" slot (T-145).
///
/// A generic, publisher-agnostic slot: a pane publishes a short status
/// string to [paneContextChannel] on the MessageBus, and the bottom
/// status bar shows the latest one. The active pane publishes (an
/// inactive pane stays quiet), so switching tabs swaps the slot to the
/// newly-active pane's message. The Claude pane is the first publisher
/// (model · permission-mode · context); other panes can use the same
/// channel.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// MessageBus channel for the status-bar context slot. Data: `{'text': String}`.
const paneContextChannel = 'statusbar.context';

/// Publish [text] to the context slot (empty string clears it).
void publishPaneContext(MessageBus messages, String publisher, String text) {
  messages.publish(publisher, paneContextChannel, {'text': text});
}

/// Status-bar item that shows the latest pane-context message (nothing
/// when empty). Subscribes to the bus itself via the ambient kernel.
class PaneContextStatusItem extends StatefulWidget {
  const PaneContextStatusItem({super.key});

  @override
  State<PaneContextStatusItem> createState() => _PaneContextStatusItemState();
}

class _PaneContextStatusItemState extends State<PaneContextStatusItem> {
  StreamSubscription<Message>? _sub;
  String _text = '';
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    _subscribed = true;
    final messages = ClideKernel.of(context).messages;
    _sub = messages.subscribe(channel: paneContextChannel).listen((m) {
      final t = (m.data['text'] as String?) ?? '';
      if (t == _text || !mounted) return;
      setState(() => _text = t);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_text.isEmpty) return const SizedBox.shrink();
    final tokens = ClideTheme.of(context).surface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClideText(
        _text,
        fontSize: clideFontSmall,
        fontFamily: clideMonoFamily,
        color: tokens.statusBarForeground,
        maxLines: 1,
      ),
    );
  }
}
