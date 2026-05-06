import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Resolved surface tokens — the only thing widgets consume.
///
/// The token surface grows as features need more of it. Every token
/// declared here must have a default resolution in
/// `_defaultSurfaceMap` (resolver.dart) so legacy palette-only themes
/// produce a complete SurfaceTokens without declaring the full surface.
@immutable
class SurfaceTokens {
  const SurfaceTokens({
    // global
    required this.globalForeground,
    required this.globalBackground,
    required this.globalBorder,
    required this.globalFocus,
    required this.globalTextMuted,
    // chrome (hat bar, sidebar, status bar, spines — frame surfaces)
    required this.chromeBackground,
    required this.chromeForeground,
    required this.chromeBorder,
    // panel
    required this.panelBackground,
    required this.panelBorder,
    required this.panelActiveBorder,
    required this.panelHeader,
    required this.panelHeaderForeground,
    // sidebar
    required this.sidebarBackground,
    required this.sidebarForeground,
    required this.sidebarItemHover,
    required this.sidebarItemSelected,
    required this.sidebarSectionHeader,
    // statusbar
    required this.statusBarBackground,
    required this.statusBarForeground,
    required this.statusBarItemActiveBackground,
    required this.statusBarItemHoverBackground,
    // tabs
    required this.tabBarBackground,
    required this.tabActive,
    required this.tabInactive,
    required this.tabActiveForeground,
    required this.tabInactiveForeground,
    required this.tabActiveBorder,
    required this.tabCloseHover,
    // buttons
    required this.buttonBackground,
    required this.buttonForeground,
    required this.buttonHoverBackground,
    required this.buttonActiveBackground,
    required this.buttonBorder,
    // list items
    required this.listItemBackground,
    required this.listItemForeground,
    required this.listItemHoverBackground,
    required this.listItemSelectedBackground,
    required this.listItemSelectedForeground,
    // scrollbar
    required this.scrollbarSlider,
    required this.scrollbarSliderHover,
    required this.scrollbarTrack,
    // tooltip
    required this.tooltipBackground,
    required this.tooltipForeground,
    required this.tooltipBorder,
    // dropdown
    required this.dropdownBackground,
    required this.dropdownForeground,
    required this.dropdownBorder,
    // modal
    required this.modalOverlayBackground,
    required this.modalSurfaceBackground,
    required this.modalSurfaceBorder,
    // divider
    required this.dividerColor,
    // status
    required this.statusSuccess,
    required this.statusWarning,
    required this.statusError,
    required this.statusInfo,
    // syntax
    required this.syntaxKeyword,
    required this.syntaxType,
    required this.syntaxString,
    required this.syntaxNumber,
    required this.syntaxComment,
    required this.syntaxMethod,
    required this.syntaxPunct,
    required this.extensionTokens,
  });

  final Color globalForeground;
  final Color globalBackground;
  final Color globalBorder;
  final Color globalFocus;
  final Color globalTextMuted;

  final Color chromeBackground;
  final Color chromeForeground;
  final Color chromeBorder;

  final Color panelBackground;
  final Color panelBorder;
  final Color panelActiveBorder;
  final Color panelHeader;
  final Color panelHeaderForeground;

  final Color sidebarBackground;
  final Color sidebarForeground;
  final Color sidebarItemHover;
  final Color sidebarItemSelected;
  final Color sidebarSectionHeader;

  final Color statusBarBackground;
  final Color statusBarForeground;
  final Color statusBarItemActiveBackground;
  final Color statusBarItemHoverBackground;

  final Color tabBarBackground;
  final Color tabActive;
  final Color tabInactive;
  final Color tabActiveForeground;
  final Color tabInactiveForeground;
  final Color tabActiveBorder;
  final Color tabCloseHover;

  final Color buttonBackground;
  final Color buttonForeground;
  final Color buttonHoverBackground;
  final Color buttonActiveBackground;
  final Color buttonBorder;

  final Color listItemBackground;
  final Color listItemForeground;
  final Color listItemHoverBackground;
  final Color listItemSelectedBackground;
  final Color listItemSelectedForeground;

  final Color scrollbarSlider;
  final Color scrollbarSliderHover;
  final Color scrollbarTrack;

  final Color tooltipBackground;
  final Color tooltipForeground;
  final Color tooltipBorder;

  final Color dropdownBackground;
  final Color dropdownForeground;
  final Color dropdownBorder;

  final Color modalOverlayBackground;
  final Color modalSurfaceBackground;
  final Color modalSurfaceBorder;

  final Color dividerColor;

  final Color statusSuccess;
  final Color statusWarning;
  final Color statusError;
  final Color statusInfo;

  final Color syntaxKeyword;
  final Color syntaxType;
  final Color syntaxString;
  final Color syntaxNumber;
  final Color syntaxComment;
  final Color syntaxMethod;
  final Color syntaxPunct;

  /// Extension-declared tokens keyed by their dotted path
  /// (e.g. `ext.sqlite.table.background`).
  final Map<String, Color> extensionTokens;
}

/// Canonical surface-token keys as they appear in YAML.
///
/// Keeping them in one place lets the loader, the resolver, and the
/// default map reference the same strings without typos.
abstract class TokenKeys {
  // global
  static const globalForeground = 'global.foreground';
  static const globalBackground = 'global.background';
  static const globalBorder = 'global.border';
  static const globalFocus = 'global.focus';
  static const globalTextMuted = 'global.textMuted';

  // chrome
  static const chromeBackground = 'chrome.background';
  static const chromeForeground = 'chrome.foreground';
  static const chromeBorder = 'chrome.border';

  // panel
  static const panelBackground = 'panel.background';
  static const panelBorder = 'panel.border';
  static const panelActiveBorder = 'panel.activeBorder';
  static const panelHeader = 'panel.header';
  static const panelHeaderForeground = 'panel.headerForeground';

  // sidebar
  static const sidebarBackground = 'sidebar.background';
  static const sidebarForeground = 'sidebar.foreground';
  static const sidebarItemHover = 'sidebar.itemHover';
  static const sidebarItemSelected = 'sidebar.itemSelected';
  static const sidebarSectionHeader = 'sidebar.sectionHeader';

  // statusbar
  static const statusBarBackground = 'statusBar.background';
  static const statusBarForeground = 'statusBar.foreground';
  static const statusBarItemActiveBackground = 'statusBar.itemActiveBackground';
  static const statusBarItemHoverBackground = 'statusBar.itemHoverBackground';

  // tabs
  static const tabBarBackground = 'tabBar.background';
  static const tabActive = 'tabBar.tabActive';
  static const tabInactive = 'tabBar.tabInactive';
  static const tabActiveForeground = 'tabBar.tabActiveForeground';
  static const tabInactiveForeground = 'tabBar.tabInactiveForeground';
  static const tabActiveBorder = 'tabBar.tabActiveBorder';
  static const tabCloseHover = 'tabBar.tabCloseHover';

  // buttons
  static const buttonBackground = 'button.background';
  static const buttonForeground = 'button.foreground';
  static const buttonHoverBackground = 'button.hoverBackground';
  static const buttonActiveBackground = 'button.activeBackground';
  static const buttonBorder = 'button.border';

  // list items
  static const listItemBackground = 'listItem.background';
  static const listItemForeground = 'listItem.foreground';
  static const listItemHoverBackground = 'listItem.hoverBackground';
  static const listItemSelectedBackground = 'listItem.selectedBackground';
  static const listItemSelectedForeground = 'listItem.selectedForeground';

  // scrollbar
  static const scrollbarSlider = 'scrollbar.slider';
  static const scrollbarSliderHover = 'scrollbar.sliderHover';
  static const scrollbarTrack = 'scrollbar.track';

  // tooltip
  static const tooltipBackground = 'tooltip.background';
  static const tooltipForeground = 'tooltip.foreground';
  static const tooltipBorder = 'tooltip.border';

  // dropdown
  static const dropdownBackground = 'dropdown.background';
  static const dropdownForeground = 'dropdown.foreground';
  static const dropdownBorder = 'dropdown.border';

  // modal
  static const modalOverlayBackground = 'modal.overlayBackground';
  static const modalSurfaceBackground = 'modal.surfaceBackground';
  static const modalSurfaceBorder = 'modal.surfaceBorder';

  // divider
  static const dividerColor = 'divider.color';

  // status
  static const statusSuccess = 'status.success';
  static const statusWarning = 'status.warning';
  static const statusError = 'status.error';
  static const statusInfo = 'status.info';

  // syntax
  static const syntaxKeyword = 'syntax.keyword';
  static const syntaxType = 'syntax.type';
  static const syntaxString = 'syntax.string';
  static const syntaxNumber = 'syntax.number';
  static const syntaxComment = 'syntax.comment';
  static const syntaxMethod = 'syntax.method';
  static const syntaxPunct = 'syntax.punct';

  static const all = <String>[
    globalForeground,
    globalBackground,
    globalBorder,
    globalFocus,
    globalTextMuted,
    chromeBackground,
    chromeForeground,
    chromeBorder,
    panelBackground,
    panelBorder,
    panelActiveBorder,
    panelHeader,
    panelHeaderForeground,
    sidebarBackground,
    sidebarForeground,
    sidebarItemHover,
    sidebarItemSelected,
    sidebarSectionHeader,
    statusBarBackground,
    statusBarForeground,
    statusBarItemActiveBackground,
    statusBarItemHoverBackground,
    tabBarBackground,
    tabActive,
    tabInactive,
    tabActiveForeground,
    tabInactiveForeground,
    tabActiveBorder,
    tabCloseHover,
    buttonBackground,
    buttonForeground,
    buttonHoverBackground,
    buttonActiveBackground,
    buttonBorder,
    listItemBackground,
    listItemForeground,
    listItemHoverBackground,
    listItemSelectedBackground,
    listItemSelectedForeground,
    scrollbarSlider,
    scrollbarSliderHover,
    scrollbarTrack,
    tooltipBackground,
    tooltipForeground,
    tooltipBorder,
    dropdownBackground,
    dropdownForeground,
    dropdownBorder,
    modalOverlayBackground,
    modalSurfaceBackground,
    modalSurfaceBorder,
    dividerColor,
    statusSuccess,
    statusWarning,
    statusError,
    statusInfo,
    syntaxKeyword,
    syntaxType,
    syntaxString,
    syntaxNumber,
    syntaxComment,
    syntaxMethod,
    syntaxPunct,
  ];
}
