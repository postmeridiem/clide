import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// The Extensions settings tab's "watch this space" notice (T-456).
///
/// Built-in extensions are always on and there's no third-party install path
/// yet, so there's nothing to manage. Rather than ship a toggle list that could
/// brick the app, the tab explains that extension management arrives with
/// third-party (Lua) extensions and points at the records that track it.
/// Rendered inside the section card (no own surface) via the custom-control
/// registry.
class ExtensionsNotice extends StatelessWidget {
  const ExtensionsNotice({super.key});

  static const ns = 'builtin.extensions-ui';

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final i = ClideSettings.i18n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClideIcon(PhosphorIcons.byName('puzzle-piece'), size: 18, color: tokens.globalTextMuted),
            const SizedBox(width: 8),
            ClideText(
              i.string('notice.title', namespace: ns, placeholder: 'Extension management is coming'),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClideText(
          i.string(
            'notice.body',
            namespace: ns,
            placeholder:
                'Installing, enabling, and disabling extensions arrives with third-party (Lua) extension support. For now the built-in extensions are always on.',
          ),
          color: tokens.globalTextMuted,
        ),
        const SizedBox(height: 10),
        ClideText(
          i.string('notice.tracked', namespace: ns, placeholder: 'Tracked in T-8 (Tier 6) · D-16'),
          color: tokens.globalTextMuted,
          fontSize: clideFontCaption,
          fontFamily: ClideSettings.fonts.monoOf(context),
        ),
      ],
    );
  }
}
