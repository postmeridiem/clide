import 'dart:async';

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
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final Duration debounce;
  final ValueChanged<String>? onSubmitted;

  @override
  State<ClideFilterBox> createState() => _ClideFilterBoxState();
}

class _ClideFilterBoxState extends State<ClideFilterBox> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () => widget.onChanged(value));
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    _debounceTimer?.cancel();
    widget.onChanged('');
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
              ClideIcon(PhosphorIcons.magnifyingGlass, size: 13, color: tokens.globalTextMuted),
              const SizedBox(width: 6),
              Expanded(
                child: EditableText(
                  controller: _controller,
                  focusNode: _focus,
                  style: TextStyle(fontSize: clideFontCaption, color: tokens.globalForeground),
                  cursorColor: tokens.globalFocus,
                  backgroundCursorColor: tokens.globalTextMuted,
                  maxLines: 1,
                  onChanged: _onChanged,
                  onSubmitted: widget.onSubmitted != null ? (v) => widget.onSubmitted!(v) : null,
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
