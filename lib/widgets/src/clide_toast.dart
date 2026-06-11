import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/icons/phosphor.dart';
import 'package:clide/widgets/src/spacing.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

/// Maps a [ToastSeverity] to its status token + leading glyph. Kept here
/// (render layer) so the [ToastService] stays theme-free.
({Color color, ClideIconPainter icon}) _styleFor(ToastSeverity s, SurfaceTokens t) {
  switch (s) {
    case ToastSeverity.success:
      return (color: t.statusSuccess, icon: PhosphorIcons.byName('check-circle'));
    case ToastSeverity.warning:
      return (color: t.statusWarning, icon: PhosphorIcons.byName('warning-circle'));
    case ToastSeverity.error:
      return (color: t.statusError, icon: PhosphorIcons.byName('warning-circle'));
    case ToastSeverity.info:
      return (color: t.statusInfo, icon: PhosphorIcons.byName('circles-four'));
  }
}

/// A single toast card (T-50). Severity-colored leading accent + glyph, the
/// message, and a dismiss affordance. Slides + fades in on mount; clipped to
/// a bounded width. No Material — a plain themed container (D-7).
class ClideToast extends StatefulWidget {
  const ClideToast({super.key, required this.entry, required this.onDismiss});

  final ToastEntry entry;
  final VoidCallback onDismiss;

  @override
  State<ClideToast> createState() => _ClideToastState();
}

class _ClideToastState extends State<ClideToast> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // Flip after the first frame so the implicit animations run once, then
    // settle (no perpetual ticker — keeps widget tests deterministic).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final style = _styleFor(widget.entry.severity, tokens);
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0.25, 0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: widget.entry.message,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              decoration: BoxDecoration(
                color: tokens.dropdownBackground,
                border: Border(left: BorderSide(color: style.color, width: 3)),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(color: tokens.shadowAmbient, blurRadius: 8, offset: const Offset(0, 2))],
              ),
              padding: const EdgeInsets.fromLTRB(clideInsetText, clideInsetStandard, clideInsetStandard, clideInsetStandard),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClideIcon(style.icon, size: clideIconStandard, color: style.color),
                  const SizedBox(width: clideGapStandard),
                  Flexible(
                    child: ClideText(widget.entry.message, fontSize: clideFontBody, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: clideGapStandard),
                  Semantics(
                    button: true,
                    label: 'Dismiss notification',
                    child: ClideTappable(
                      onTap: widget.onDismiss,
                      builder: (ctx, hovered, _) =>
                          ClideIcon(PhosphorIcons.byName('x'), size: clideIconStandard, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders the live [ToastService] queue anchored bottom-right (T-50).
/// Mounted as a child of the app-root [Stack] (alongside the palette /
/// quick-open overlays). Occupies only its corner — non-toast space stays
/// interactive. Newest toast sits at the bottom.
class ToastOverlay extends StatefulWidget {
  const ToastOverlay({super.key});

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<ToastOverlay> {
  ToastService? _toast;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ClideKernel.of(context).toast;
    if (!identical(_toast, next)) {
      _toast?.removeListener(_onChanged);
      _toast = next;
      _toast!.addListener(_onChanged);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _toast?.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _toast?.entries ?? const <ToastEntry>[];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Positioned(
      right: clideGapMajor,
      bottom: clideGapMajor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in entries) ...[
            ClideToast(key: ValueKey('toast.${e.id}'), entry: e, onDismiss: () => _toast?.dismiss(e.id)),
            const SizedBox(height: clideGapStandard),
          ],
        ],
      ),
    );
  }
}
