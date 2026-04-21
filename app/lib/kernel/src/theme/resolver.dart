import 'dart:ui';

import 'package:clide_app/kernel/src/theme/palette.dart';
import 'package:clide_app/kernel/src/theme/semantic.dart';
import 'package:clide_app/kernel/src/theme/tokens.dart';

/// Three-tier theme resolution.
///
///   palette  (raw colors)
///     ↓ (ref-chain; defaults inherited)
///   semantic (role → palette)
///     ↓ (ref-chain; defaults inherited)
///   surface  (token → semantic|palette|literal)
///
/// References take the form:
///   `semantic.<role>` — look up in [semantic]
///   `#rrggbb` / `#aarrggbb` — literal hex
///   bare name         — palette lookup
class ThemeResolver {
  const ThemeResolver();

  SurfaceTokens resolve({
    required Palette palette,
    SemanticRoles? semanticOverride,
    Map<String, String>? surfaceOverride,
    Map<String, String>? extensionOverride,
  }) {
    final semantic = _buildSemantic(palette, semanticOverride);
    final surface = <String, Color>{};
    for (final key in TokenKeys.all) {
      surface[key] = _resolveSurface(
        key: key,
        palette: palette,
        semantic: semantic,
        surfaceOverride: surfaceOverride,
      );
    }

    final extTokens = <String, Color>{};
    if (extensionOverride != null) {
      for (final entry in extensionOverride.entries) {
        final resolved = _resolveRef(entry.value, palette, semantic);
        if (resolved != null) extTokens[entry.key] = resolved;
      }
    }

    return SurfaceTokens(
      globalForeground: surface[TokenKeys.globalForeground]!,
      globalBackground: surface[TokenKeys.globalBackground]!,
      globalBorder: surface[TokenKeys.globalBorder]!,
      globalFocus: surface[TokenKeys.globalFocus]!,
      globalTextMuted: surface[TokenKeys.globalTextMuted]!,
      panelBackground: surface[TokenKeys.panelBackground]!,
      panelBorder: surface[TokenKeys.panelBorder]!,
      panelActiveBorder: surface[TokenKeys.panelActiveBorder]!,
      panelHeader: surface[TokenKeys.panelHeader]!,
      panelHeaderForeground: surface[TokenKeys.panelHeaderForeground]!,
      sidebarBackground: surface[TokenKeys.sidebarBackground]!,
      sidebarForeground: surface[TokenKeys.sidebarForeground]!,
      sidebarItemHover: surface[TokenKeys.sidebarItemHover]!,
      sidebarItemSelected: surface[TokenKeys.sidebarItemSelected]!,
      sidebarSectionHeader: surface[TokenKeys.sidebarSectionHeader]!,
      statusBarBackground: surface[TokenKeys.statusBarBackground]!,
      statusBarForeground: surface[TokenKeys.statusBarForeground]!,
      statusBarItemActiveBackground:
          surface[TokenKeys.statusBarItemActiveBackground]!,
      statusBarItemHoverBackground:
          surface[TokenKeys.statusBarItemHoverBackground]!,
      tabBarBackground: surface[TokenKeys.tabBarBackground]!,
      tabActive: surface[TokenKeys.tabActive]!,
      tabInactive: surface[TokenKeys.tabInactive]!,
      tabActiveForeground: surface[TokenKeys.tabActiveForeground]!,
      tabInactiveForeground: surface[TokenKeys.tabInactiveForeground]!,
      tabActiveBorder: surface[TokenKeys.tabActiveBorder]!,
      tabCloseHover: surface[TokenKeys.tabCloseHover]!,
      buttonBackground: surface[TokenKeys.buttonBackground]!,
      buttonForeground: surface[TokenKeys.buttonForeground]!,
      buttonHoverBackground: surface[TokenKeys.buttonHoverBackground]!,
      buttonActiveBackground: surface[TokenKeys.buttonActiveBackground]!,
      buttonBorder: surface[TokenKeys.buttonBorder]!,
      listItemBackground: surface[TokenKeys.listItemBackground]!,
      listItemForeground: surface[TokenKeys.listItemForeground]!,
      listItemHoverBackground: surface[TokenKeys.listItemHoverBackground]!,
      listItemSelectedBackground:
          surface[TokenKeys.listItemSelectedBackground]!,
      listItemSelectedForeground:
          surface[TokenKeys.listItemSelectedForeground]!,
      scrollbarSlider: surface[TokenKeys.scrollbarSlider]!,
      scrollbarSliderHover: surface[TokenKeys.scrollbarSliderHover]!,
      scrollbarTrack: surface[TokenKeys.scrollbarTrack]!,
      tooltipBackground: surface[TokenKeys.tooltipBackground]!,
      tooltipForeground: surface[TokenKeys.tooltipForeground]!,
      tooltipBorder: surface[TokenKeys.tooltipBorder]!,
      dropdownBackground: surface[TokenKeys.dropdownBackground]!,
      dropdownForeground: surface[TokenKeys.dropdownForeground]!,
      dropdownBorder: surface[TokenKeys.dropdownBorder]!,
      modalOverlayBackground: surface[TokenKeys.modalOverlayBackground]!,
      modalSurfaceBackground: surface[TokenKeys.modalSurfaceBackground]!,
      modalSurfaceBorder: surface[TokenKeys.modalSurfaceBorder]!,
      dividerColor: surface[TokenKeys.dividerColor]!,
      statusSuccess: surface[TokenKeys.statusSuccess]!,
      statusWarning: surface[TokenKeys.statusWarning]!,
      statusError: surface[TokenKeys.statusError]!,
      statusInfo: surface[TokenKeys.statusInfo]!,
      extensionTokens: extTokens,
    );
  }

  SemanticRoles _buildSemantic(Palette palette, SemanticRoles? override) {
    final roles = <String, Color>{};
    for (final role in SemanticKeys.all) {
      final fromOverride = override?.lookup(role);
      if (fromOverride != null) {
        roles[role] = fromOverride;
        continue;
      }
      for (final candidate in _defaultSemanticFallbacks[role] ?? [role]) {
        final fromPalette = palette.lookup(candidate);
        if (fromPalette != null) {
          roles[role] = fromPalette;
          break;
        }
      }
      // If still unresolved, fall back to foreground/background so the
      // theme never has a null surface color. Themes that omit these
      // will land readable if uninspired.
      roles.putIfAbsent(role, () {
        return palette.lookup('foreground') ??
            palette.lookup('background') ??
            const Color(0xFFFFFFFF);
      });
    }
    return SemanticRoles(roles);
  }

  Color _resolveSurface({
    required String key,
    required Palette palette,
    required SemanticRoles semantic,
    Map<String, String>? surfaceOverride,
  }) {
    final override = surfaceOverride?[key];
    if (override != null) {
      final resolved = _resolveRef(override, palette, semantic);
      if (resolved != null) return resolved;
    }
    final defaultRef = _defaultSurfaceMap[key];
    if (defaultRef != null) {
      final resolved = _resolveRef(defaultRef, palette, semantic);
      if (resolved != null) return resolved;
    }
    // Last-ditch: something has to render. Fall back to semantic text.
    return semantic.lookup(SemanticKeys.text) ?? const Color(0xFFFFFFFF);
  }

  Color? _resolveRef(String ref, Palette palette, SemanticRoles semantic) {
    if (ref.startsWith('#')) return Palette.parseHex(ref);
    if (ref.startsWith('semantic.')) {
      return semantic.lookup(ref.substring('semantic.'.length));
    }
    return palette.lookup(ref);
  }
}

/// Default palette names a semantic role will try, in order, when the
/// theme doesn't override the role explicitly.
const Map<String, List<String>> _defaultSemanticFallbacks = {
  SemanticKeys.mainchrome: ['panel', 'surface', 'background'],
  SemanticKeys.calltoaction: ['accent', 'primary'],
  SemanticKeys.focus: ['primary', 'accent'],
  SemanticKeys.background: ['background'],
  SemanticKeys.surface: ['surface', 'panel'],
  SemanticKeys.text: ['foreground'],
  SemanticKeys.textMuted: ['muted', 'secondary', 'foreground'],
  SemanticKeys.success: ['success'],
  SemanticKeys.warning: ['warning'],
  SemanticKeys.error: ['error'],
  SemanticKeys.info: ['info', 'primary'],
};

/// Default surface map. Every entry resolves through the semantic layer
/// where it makes sense; raw palette refs are used only where the
/// semantic layer doesn't have a role that fits.
const Map<String, String> _defaultSurfaceMap = {
  TokenKeys.globalForeground: 'semantic.text',
  TokenKeys.globalBackground: 'semantic.background',
  TokenKeys.globalBorder: 'semantic.surface',
  TokenKeys.globalFocus: 'semantic.focus',
  TokenKeys.globalTextMuted: 'semantic.text_muted',
  TokenKeys.panelBackground: 'semantic.mainchrome',
  TokenKeys.panelBorder: 'semantic.surface',
  TokenKeys.panelActiveBorder: 'semantic.focus',
  TokenKeys.panelHeader: 'semantic.mainchrome',
  TokenKeys.panelHeaderForeground: 'semantic.text',
  TokenKeys.sidebarBackground: 'semantic.mainchrome',
  TokenKeys.sidebarForeground: 'semantic.text',
  TokenKeys.sidebarItemHover: 'semantic.surface',
  TokenKeys.sidebarItemSelected: 'semantic.focus',
  TokenKeys.sidebarSectionHeader: 'semantic.text_muted',
  TokenKeys.statusBarBackground: 'semantic.mainchrome',
  TokenKeys.statusBarForeground: 'semantic.text',
  TokenKeys.statusBarItemActiveBackground: 'semantic.focus',
  TokenKeys.statusBarItemHoverBackground: 'semantic.surface',
  TokenKeys.tabBarBackground: 'semantic.mainchrome',
  TokenKeys.tabActive: 'semantic.background',
  TokenKeys.tabInactive: 'semantic.mainchrome',
  TokenKeys.tabActiveForeground: 'semantic.text',
  TokenKeys.tabInactiveForeground: 'semantic.text_muted',
  TokenKeys.tabActiveBorder: 'semantic.focus',
  TokenKeys.tabCloseHover: 'semantic.error',
  TokenKeys.buttonBackground: 'semantic.surface',
  TokenKeys.buttonForeground: 'semantic.text',
  TokenKeys.buttonHoverBackground: 'semantic.mainchrome',
  TokenKeys.buttonActiveBackground: 'semantic.focus',
  TokenKeys.buttonBorder: 'semantic.surface',
  TokenKeys.listItemBackground: 'semantic.background',
  TokenKeys.listItemForeground: 'semantic.text',
  TokenKeys.listItemHoverBackground: 'semantic.surface',
  TokenKeys.listItemSelectedBackground: 'semantic.focus',
  TokenKeys.listItemSelectedForeground: 'semantic.background',
  TokenKeys.scrollbarSlider: 'semantic.surface',
  TokenKeys.scrollbarSliderHover: 'semantic.text_muted',
  TokenKeys.scrollbarTrack: 'semantic.mainchrome',
  TokenKeys.tooltipBackground: 'semantic.surface',
  TokenKeys.tooltipForeground: 'semantic.text',
  TokenKeys.tooltipBorder: 'semantic.mainchrome',
  TokenKeys.dropdownBackground: 'semantic.surface',
  TokenKeys.dropdownForeground: 'semantic.text',
  TokenKeys.dropdownBorder: 'semantic.mainchrome',
  TokenKeys.modalOverlayBackground: '#C0000000',
  TokenKeys.modalSurfaceBackground: 'semantic.mainchrome',
  TokenKeys.modalSurfaceBorder: 'semantic.focus',
  TokenKeys.dividerColor: 'semantic.surface',
  TokenKeys.statusSuccess: 'semantic.success',
  TokenKeys.statusWarning: 'semantic.warning',
  TokenKeys.statusError: 'semantic.error',
  TokenKeys.statusInfo: 'semantic.info',
};
