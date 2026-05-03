import 'dart:ui';

import 'package:clide/kernel/src/theme/palette.dart';
import 'package:clide/kernel/src/theme/semantic.dart';
import 'package:clide/kernel/src/theme/tokens.dart';

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
      chromeBackground: surface[TokenKeys.chromeBackground]!,
      chromeForeground: surface[TokenKeys.chromeForeground]!,
      chromeBorder: surface[TokenKeys.chromeBorder]!,
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
      statusBarItemActiveBackground: surface[TokenKeys.statusBarItemActiveBackground]!,
      statusBarItemHoverBackground: surface[TokenKeys.statusBarItemHoverBackground]!,
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
      listItemSelectedBackground: surface[TokenKeys.listItemSelectedBackground]!,
      listItemSelectedForeground: surface[TokenKeys.listItemSelectedForeground]!,
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
      syntaxKeyword: surface[TokenKeys.syntaxKeyword]!,
      syntaxType: surface[TokenKeys.syntaxType]!,
      syntaxString: surface[TokenKeys.syntaxString]!,
      syntaxNumber: surface[TokenKeys.syntaxNumber]!,
      syntaxComment: surface[TokenKeys.syntaxComment]!,
      syntaxMethod: surface[TokenKeys.syntaxMethod]!,
      syntaxPunct: surface[TokenKeys.syntaxPunct]!,
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
        return palette.lookup('foreground') ?? palette.lookup('background') ?? const Color(0xFFFFFFFF);
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
    final candidates = _defaultSurfaceMap[key];
    if (candidates != null) {
      for (final ref in candidates) {
        final resolved = _resolveRef(ref, palette, semantic);
        if (resolved != null) return resolved;
      }
    }
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
  SemanticKeys.mainchrome: ['bgSunken', 'panel', 'surface', 'background'],
  SemanticKeys.calltoaction: ['accent', 'primary'],
  SemanticKeys.focus: ['accent', 'primary'],
  SemanticKeys.background: ['bg', 'background'],
  SemanticKeys.surface: ['surface', 'panel'],
  SemanticKeys.text: ['textHi', 'foreground'],
  SemanticKeys.textMuted: ['textDim', 'muted', 'secondary', 'foreground'],
  SemanticKeys.success: ['ok', 'success'],
  SemanticKeys.warning: ['warn', 'warning'],
  SemanticKeys.error: ['err', 'error'],
  SemanticKeys.info: ['info', 'primary'],
};

/// Default surface map. Every entry resolves through the semantic layer
/// where it makes sense; raw palette refs are used only where the
/// semantic layer doesn't have a role that fits.
const Map<String, List<String>> _defaultSurfaceMap = {
  // global — try design keys first, then legacy semantic
  TokenKeys.globalForeground: ['textHi', 'semantic.text'],
  TokenKeys.globalBackground: ['bg', 'semantic.background'],
  TokenKeys.globalBorder: ['border', 'semantic.surface'],
  TokenKeys.globalFocus: ['accent', 'semantic.focus'],
  TokenKeys.globalTextMuted: ['textDim', 'semantic.text_muted'],
  // chrome — frame surfaces (hat bar, sidebar, status bar, spines)
  TokenKeys.chromeBackground: ['bgSunken', 'semantic.mainchrome'],
  TokenKeys.chromeForeground: ['textDim', 'semantic.text_muted'],
  TokenKeys.chromeBorder: ['border', 'semantic.surface'],
  // panel
  TokenKeys.panelBackground: ['bgSunken', 'semantic.mainchrome'],
  TokenKeys.panelBorder: ['border', 'semantic.surface'],
  TokenKeys.panelActiveBorder: ['borderHi', 'semantic.focus'],
  TokenKeys.panelHeader: ['surface', 'semantic.mainchrome'],
  TokenKeys.panelHeaderForeground: ['text', 'semantic.text'],
  // sidebar
  TokenKeys.sidebarBackground: ['bgSunken', 'semantic.mainchrome'],
  TokenKeys.sidebarForeground: ['text', 'semantic.text'],
  TokenKeys.sidebarItemHover: ['surface', 'semantic.surface'],
  TokenKeys.sidebarItemSelected: ['surfaceHi', 'semantic.focus'],
  TokenKeys.sidebarSectionHeader: ['textMute', 'semantic.text_muted'],
  // statusbar
  TokenKeys.statusBarBackground: ['bgSunken', 'semantic.mainchrome'],
  TokenKeys.statusBarForeground: ['text', 'semantic.text'],
  TokenKeys.statusBarItemActiveBackground: ['accent', 'semantic.focus'],
  TokenKeys.statusBarItemHoverBackground: ['surface', 'semantic.surface'],
  // tabs
  TokenKeys.tabBarBackground: ['bgSunken', 'semantic.mainchrome'],
  TokenKeys.tabActive: ['bg', 'semantic.background'],
  TokenKeys.tabInactive: ['bgSunken', 'semantic.mainchrome'],
  TokenKeys.tabActiveForeground: ['textHi', 'semantic.text'],
  TokenKeys.tabInactiveForeground: ['textDim', 'semantic.text_muted'],
  TokenKeys.tabActiveBorder: ['accent', 'semantic.focus'],
  TokenKeys.tabCloseHover: ['err', 'semantic.error'],
  // buttons
  TokenKeys.buttonBackground: ['accent', 'semantic.calltoaction'],
  TokenKeys.buttonForeground: ['onAccent', 'semantic.background'],
  TokenKeys.buttonHoverBackground: ['accentPress', 'semantic.focus'],
  TokenKeys.buttonActiveBackground: ['accentPress', 'semantic.focus'],
  TokenKeys.buttonBorder: ['border', 'semantic.surface'],
  // list items
  TokenKeys.listItemBackground: ['bg', 'semantic.background'],
  TokenKeys.listItemForeground: ['text', 'semantic.text'],
  TokenKeys.listItemHoverBackground: ['surface', 'semantic.surface'],
  TokenKeys.listItemSelectedBackground: ['surfaceHi', 'semantic.focus'],
  TokenKeys.listItemSelectedForeground: ['textHi', 'semantic.text'],
  // scrollbar
  TokenKeys.scrollbarSlider: ['border', 'semantic.surface'],
  TokenKeys.scrollbarSliderHover: ['borderHi', 'semantic.text_muted'],
  TokenKeys.scrollbarTrack: ['bgSunken', 'semantic.mainchrome'],
  // tooltip
  TokenKeys.tooltipBackground: ['surface', 'semantic.surface'],
  TokenKeys.tooltipForeground: ['textHi', 'semantic.text'],
  TokenKeys.tooltipBorder: ['borderHi', 'semantic.mainchrome'],
  // dropdown
  TokenKeys.dropdownBackground: ['surface', 'semantic.surface'],
  TokenKeys.dropdownForeground: ['text', 'semantic.text'],
  TokenKeys.dropdownBorder: ['border', 'semantic.mainchrome'],
  // modal
  TokenKeys.modalOverlayBackground: ['#C0000000'],
  TokenKeys.modalSurfaceBackground: ['surface', 'semantic.mainchrome'],
  TokenKeys.modalSurfaceBorder: ['accent', 'semantic.focus'],
  // divider
  TokenKeys.dividerColor: ['border', 'semantic.surface'],
  // status
  TokenKeys.statusSuccess: ['ok', 'semantic.success'],
  TokenKeys.statusWarning: ['warn', 'semantic.warning'],
  TokenKeys.statusError: ['err', 'semantic.error'],
  TokenKeys.statusInfo: ['info', 'semantic.info'],
  TokenKeys.syntaxKeyword: ['semantic.calltoaction'],
  TokenKeys.syntaxType: ['semantic.info'],
  TokenKeys.syntaxString: ['semantic.success'],
  TokenKeys.syntaxNumber: ['semantic.warning'],
  TokenKeys.syntaxComment: ['semantic.text_muted'],
  TokenKeys.syntaxMethod: ['semantic.focus'],
  TokenKeys.syntaxPunct: ['semantic.text_muted'],
};
