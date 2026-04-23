import 'package:flutter/widgets.dart';

class ClideTappable extends StatefulWidget {
  const ClideTappable({
    super.key,
    required this.onTap,
    required this.builder,
    this.cursor = SystemMouseCursors.click,
  });

  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;

  @override
  State<ClideTappable> createState() => _ClideTappableState();
}

class _ClideTappableState extends State<ClideTappable> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(context, _hover),
      ),
    );
  }
}
