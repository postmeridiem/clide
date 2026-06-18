import 'package:clide/kernel/src/facade.dart' show ClideKernel;
import 'package:clide/kernel/src/i18n/i18n.dart' show I18n, I18nReplacer;
// Re-export so ClideSettings.i18n.interpolated callers get I18nReplacer with
// the facade (via the widgets barrel) — the templated-lookup API is then
// self-contained (T-462).
export 'package:clide/kernel/src/i18n/i18n.dart' show I18nReplacer;
import 'package:clide/kernel/src/theme/controller.dart' show ClideTheme, ClideThemeData;
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

/// One facade for the app's live user preferences — fonts, theme, and i18n —
/// read uniformly as `ClideSettings.fonts.monoOf(context)`,
/// `ClideSettings.theme.of(context)`, `ClideSettings.i18n.of(context)`. Plumb
/// once at the root, use many (D-101).
///
/// The values all originate in the kernel `SettingsStore`; this is the
/// widget-facing read side. Fonts are carried by [ClideSettingsScope] (the root
/// resolves them from the font settings and rebuilds on change, so dependents
/// re-read live). Theme and i18n **delegate** to their existing live providers
/// ([ClideTheme] / the `I18n` service) rather than duplicating them — one source
/// of truth, and consumers migrate onto this facade incrementally. Reads
/// outside a [ClideSettingsScope] fall back to the bundled font defaults, so a
/// widget never needs the scope to render (isolated tests).
abstract final class ClideSettings {
  static const fonts = _Fonts();
  static const theme = _Theme();
  static const i18n = _I18n();
}

class _Fonts {
  const _Fonts();

  /// The active monospace family in scope, else the bundled default.
  String monoOf(BuildContext context) => ClideSettingsScope.of(context)?.mono ?? clideMonoFamily;

  /// The active UI family in scope, else the bundled default.
  String uiOf(BuildContext context) => ClideSettingsScope.of(context)?.ui ?? clideUiFamily;
}

class _Theme {
  const _Theme();

  /// Resolved theme data for [context] — delegates to the [ClideTheme] provider.
  ClideThemeData of(BuildContext context) => ClideTheme.of(context);
}

class _I18n {
  const _I18n();

  /// The i18n service for [context] — delegates to the kernel `I18n` service.
  I18n of(BuildContext context) => ClideKernel.of(context).i18n;

  /// Resolve a catalog string through the live i18n service (D-21) — the
  /// uniform widget-facing lookup (T-462). [placeholder] is the inline English
  /// fallback. With no kernel in scope (isolated primitive tests) it returns
  /// the placeholder, so a widget never needs one to render.
  String string(BuildContext context, String key, {required String namespace, String? placeholder}) {
    final i = ClideKernel.maybeOf(context)?.i18n;
    return i == null ? (placeholder ?? key) : i.string(key, namespace: namespace, placeholder: placeholder);
  }

  /// [string] with `replaceAll` interpolation per replacer (templated labels).
  String interpolated(BuildContext context, String key, {required String namespace, String? placeholder, List<I18nReplacer> replacers = const []}) {
    final i = ClideKernel.maybeOf(context)?.i18n;
    if (i != null) return i.interpolated(key, namespace: namespace, placeholder: placeholder, replacers: replacers);
    var out = placeholder ?? key;
    for (final r in replacers) {
      out = out.replaceAll(r.from, r.replace);
    }
    return out;
  }
}

/// Root-provided InheritedWidget carrying the live font families (D-101). The
/// root rebuilds it from the font settings on change; font dependents re-read
/// via [ClideSettings.fonts]. Theme/i18n have their own providers, so they are
/// not duplicated here.
class ClideSettingsScope extends InheritedWidget {
  const ClideSettingsScope({super.key, required this.ui, required this.mono, required super.child});

  final String ui;
  final String mono;

  static ClideSettingsScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ClideSettingsScope>();

  @override
  bool updateShouldNotify(ClideSettingsScope old) => ui != old.ui || mono != old.mono;
}
