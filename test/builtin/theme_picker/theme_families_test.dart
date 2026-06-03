/// Tests for the theme-family helpers (T-237).
library;

import 'package:clide/builtin/theme_picker/src/theme_families.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:test/test.dart';

ThemeDefinition _def(String name, String display) => ThemeDefinition(name: name, displayName: display, dark: true, palette: Palette(const {}));

void main() {
  final all = [
    _def('clide', 'Clide'),
    _def('clide-hc', 'Clide (high contrast)'),
    _def('midnight', 'Midnight'),
    _def('midnight-hc', 'Midnight (high contrast)'),
    _def('catppuccin-mocha', 'Catppuccin Mocha'),
    _def('catppuccin-mocha-hc', 'Catppuccin Mocha (high contrast)'),
    _def('paper', 'Paper'), // no -hc sibling in this fixture
  ];

  test('isHcName / baseThemeName', () {
    expect(isHcName('midnight-hc'), isTrue);
    expect(isHcName('midnight'), isFalse);
    expect(baseThemeName('midnight-hc'), 'midnight');
    expect(baseThemeName('catppuccin-mocha-hc'), 'catppuccin-mocha');
    expect(baseThemeName('clide'), 'clide');
  });

  test('baseThemes drops -hc/-cb and sorts by display name', () {
    final bases = baseThemes(all).map((t) => t.name).toList();
    expect(bases, ['catppuccin-mocha', 'clide', 'midnight', 'paper']); // alphabetical by display
    expect(bases.any(isHcName), isFalse);
  });

  test('hasHcSibling + resolveThemeName', () {
    expect(hasHcSibling(all, 'midnight'), isTrue);
    expect(hasHcSibling(all, 'paper'), isFalse);
    expect(resolveThemeName(all, 'midnight', highContrast: true), 'midnight-hc');
    expect(resolveThemeName(all, 'midnight', highContrast: false), 'midnight');
    // No sibling → falls back to the base even when high contrast is on.
    expect(resolveThemeName(all, 'paper', highContrast: true), 'paper');
  });
}
