import 'dart:async';

import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/facade.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/icons/phosphor.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

class ClideFilterBox extends StatefulWidget {
  const ClideFilterBox({
    super.key,
    required this.onChanged,
    this.hint = 'Filter…',
    this.debounce = const Duration(milliseconds: 200),
    this.onSubmitted,
    this.icon = PhosphorIcons.magnifyingGlass,
    this.address,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final Duration debounce;
  final ValueChanged<String>? onSubmitted;

  /// Leading glyph. Defaults to the search glass; pass null for inputs
  /// that aren't searches (e.g. a replace or glob field).
  final ClideIconPainter? icon;

  /// Makes this box addressable from the CLI (D-6 parity, T-270). When set,
  /// the box listens on the MessageBus `filter.set` channel for its address
  /// — so `clide ui filter <address> <text>` drives it exactly as a UI
  /// keystroke would — and republishes its value on `filter.state` so the
  /// observe-half (`clide ui filter <address>`) can read it back. The
  /// address is the pane/box id surfaced by `clide pane list`. When null the
  /// box is a plain UI-only widget and never touches the kernel.
  final String? address;

  @override
  State<ClideFilterBox> createState() => _ClideFilterBoxState();
}

class _ClideFilterBoxState extends State<ClideFilterBox> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounceTimer;
  StreamSubscription<Message>? _busSub;
  MessageBus? _bus;
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final address = widget.address;
    if (address == null || _wired) return;
    _wired = true;
    final bus = ClideKernel.of(context).messages;
    _bus = bus;
    _busSub = bus.subscribe(publisher: address, channel: 'filter.set').listen(_onRemoteSet);
    // Report the initial value so an observe before any change still reads it.
    _publishState(_controller.text);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _busSub?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Apply a value pushed in over the bus. Programmatic sets take effect
  /// immediately (no debounce) and report their new state.
  void _onRemoteSet(Message m) {
    final value = m.data['query'] as String? ?? '';
    _debounceTimer?.cancel();
    _controller.text = value;
    widget.onChanged(value);
    _publishState(value);
    setState(() {});
  }

  void _publishState(String value) {
    final address = widget.address;
    if (address == null) return;
    _bus?.publish(address, 'filter.state', {'query': value});
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () {
      widget.onChanged(value);
      _publishState(value);
    });
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    _debounceTimer?.cancel();
    widget.onChanged('');
    _publishState('');
    _focus.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final hasText = _controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Semantics(
        label: widget.hint,
        textField: true,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.globalBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                ClideIcon(widget.icon!, size: 13, color: tokens.globalTextMuted),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Placeholder shown while empty — the hint was only a
                    // semantics label before, so empty boxes looked blank.
                    if (!hasText)
                      IgnorePointer(
                        child: Text(
                          widget.hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: clideFontCaption, color: tokens.globalTextMuted),
                        ),
                      ),
                    EditableText(
                      controller: _controller,
                      focusNode: _focus,
                      style: TextStyle(fontSize: clideFontCaption, color: tokens.globalForeground),
                      cursorColor: tokens.globalFocus,
                      backgroundCursorColor: tokens.globalTextMuted,
                      maxLines: 1,
                      onChanged: _onChanged,
                      onSubmitted: widget.onSubmitted != null ? (v) => widget.onSubmitted!(v) : null,
                    ),
                  ],
                ),
              ),
              if (hasText)
                GestureDetector(
                  onTap: _clear,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ClideIcon(PhosphorIcons.xMark, size: 11, color: tokens.globalTextMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
