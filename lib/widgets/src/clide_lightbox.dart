/// Full-screen zoom + pan overlay (T-252 / D-78). A reusable primitive: it
/// takes any [child] and shows it over the [DialogRouter]'s dimmed backdrop
/// (the host supplies the backdrop + outside-click dismiss). The image card is
/// its first consumer; canvas / graph / diff previews can adopt it later.
///
/// Open: content fits the viewport. Scroll wheel / pinch zooms; drag pans when
/// zoomed in; double-click resets to fit; Esc (or the close button, or a
/// backdrop click) dismisses. Min/max scale clamp. Own-the-rendering-stack:
/// Flutter's [InteractiveViewer] is the SDK-first base, with the zoom gestures
/// kept here so the UX is ours.
library;

import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/icons/phosphor.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ClideLightbox extends StatefulWidget {
  const ClideLightbox({
    super.key,
    required this.child,
    required this.onDismiss,
    this.minScale = 0.5,
    this.maxScale = 8.0,
  });

  /// The content to zoom — constrained to the viewport on open (pass an image
  /// with `fit: BoxFit.contain` so it fits, then scales on zoom).
  final Widget child;
  final VoidCallback onDismiss;
  final double minScale;
  final double maxScale;

  @override
  State<ClideLightbox> createState() => _ClideLightboxState();
}

class _ClideLightboxState extends State<ClideLightbox> {
  final TransformationController _tc = TransformationController();
  final FocusNode _focus = FocusNode(debugLabel: 'ClideLightbox');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _reset() => _tc.value = Matrix4.identity();

  void _onScroll(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final current = _tc.value.getMaxScaleOnAxis();
    final factor = e.scrollDelta.dy < 0 ? 1.12 : 1 / 1.12;
    final applied = (current * factor).clamp(widget.minScale, widget.maxScale) / current;
    if (applied == 1.0) return;
    final box = context.findRenderObject() as RenderBox?;
    final p = box == null ? Offset.zero : box.globalToLocal(e.position);
    _tc.value = _tc.value.clone()
      ..translateByDouble(p.dx, p.dy, 0, 1)
      ..scaleByDouble(applied, applied, applied, 1)
      ..translateByDouble(-p.dx, -p.dy, 0, 1);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final size = MediaQuery.of(context).size;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: SizedBox(
        // Leave a margin so the host backdrop is clickable to dismiss.
        width: size.width * 0.94,
        height: size.height * 0.94,
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerSignal: _onScroll,
                child: GestureDetector(
                  onDoubleTap: _reset,
                  child: InteractiveViewer(
                    transformationController: _tc,
                    minScale: widget.minScale,
                    maxScale: widget.maxScale,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: widget.child,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _IconChip(icon: PhosphorIcons.byName('x'), label: 'close', onTap: widget.onDismiss, tokens: tokens),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.panelHeader,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: ClideText(
                      'scroll to zoom · double-click to reset · Esc to close',
                      fontSize: clideFontMeta,
                      color: tokens.globalTextMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.label, required this.onTap, required this.tokens});
  final ClideIconPainter icon;
  final String label;
  final VoidCallback onTap;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tokens.panelHeader,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tokens.panelBorder),
            ),
            child: ClideIcon(icon, size: 16, color: tokens.globalForeground),
          ),
        ),
      ),
    );
  }
}
