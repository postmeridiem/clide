// Based on xterm.dart v4.0.0 by xuty (MIT). See LICENSE in this directory.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:clide/src/terminal/terminal.dart';

class TerminalScrollGestureHandler extends StatefulWidget {
  const TerminalScrollGestureHandler({
    super.key,
    required this.terminal,
    required this.getCellOffset,
    required this.getLineHeight,
    this.simulateScroll = true,
    required this.child,
  });

  final Terminal terminal;
  final CellOffset Function(Offset) getCellOffset;
  final double Function() getLineHeight;
  final bool simulateScroll;
  final Widget child;

  @override
  State<TerminalScrollGestureHandler> createState() =>
      _TerminalScrollGestureHandlerState();
}

class _TerminalScrollGestureHandlerState
    extends State<TerminalScrollGestureHandler> {
  var isAltBuffer = false;
  var _lastPointerPosition = Offset.zero;

  @override
  void initState() {
    widget.terminal.addListener(_onTerminalUpdated);
    isAltBuffer = widget.terminal.isUsingAltBuffer;
    super.initState();
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_onTerminalUpdated);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TerminalScrollGestureHandler oldWidget) {
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalUpdated);
      widget.terminal.addListener(_onTerminalUpdated);
      isAltBuffer = widget.terminal.isUsingAltBuffer;
    }
    super.didUpdateWidget(oldWidget);
  }

  void _onTerminalUpdated() {
    if (isAltBuffer != widget.terminal.isUsingAltBuffer) {
      isAltBuffer = widget.terminal.isUsingAltBuffer;
      setState(() {});
    }
  }

  void _sendScrollEvent(bool up) {
    final position = widget.getCellOffset(_lastPointerPosition);

    final handled = widget.terminal.mouseInput(
      up ? TerminalMouseButton.wheelUp : TerminalMouseButton.wheelDown,
      TerminalMouseButtonState.down,
      position,
    );

    if (!handled && widget.simulateScroll) {
      widget.terminal.keyInput(
        up ? TerminalKey.arrowUp : TerminalKey.arrowDown,
      );
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _lastPointerPosition = event.position;
    final lineHeight = widget.getLineHeight();
    if (lineHeight <= 0) return;
    final lines = (event.scrollDelta.dy / lineHeight).round().clamp(-5, 5);
    for (var i = 0; i < lines.abs(); i++) {
      _sendScrollEvent(lines < 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAltBuffer) return widget.child;

    // Intercept scroll at the pointer level so the inner Scrollable
    // (normal buffer) never sees the event in alt-buffer mode.
    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerDown: (event) => _lastPointerPosition = event.position,
      child: widget.child,
    );
  }
}
