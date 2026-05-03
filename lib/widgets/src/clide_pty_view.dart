import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/xterm.dart';

/// Theme-aware terminal view. Wraps xterm.dart's [TerminalView] with
/// clide token bindings, JetBrainsMono as the face, and a Semantics
/// wrapper that exposes the pane as a live region with the terminal's
/// aria label.
///
/// Callers provide the [Terminal] model; hooking its `onOutput` to an
/// IPC `pane.write` call and feeding `pane.output` event bytes into
/// `terminal.write()` is the consumer's job (typically a builtin
/// extension — see `builtin.terminal` / `builtin.claude`).
class ClidePtyView extends StatelessWidget {
  const ClidePtyView({
    super.key,
    required this.terminal,
    this.label,
    this.focusNode,
    this.autofocus = false,
    this.fontSize = clideFontMono,
  });

  final Terminal terminal;

  /// A11y label — typically the pane title ("terminal — ~/repo",
  /// "claude — primary", …).
  final String? label;

  final FocusNode? focusNode;
  final bool autofocus;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      label: label,
      textField: true,
      multiline: true,
      focusable: true,
      liveRegion: true,
      child: ColoredBox(
        color: tokens.panelBackground,
        child: TerminalView(
          terminal,
          focusNode: focusNode,
          autofocus: autofocus,
          theme: _buildTheme(tokens),
          textStyle: TerminalStyle(
            fontSize: fontSize,
            fontFamily: clideMonoFamily,
            fontFamilyFallback: clideMonoFamilyFallback,
          ),
          padding: EdgeInsets.zero,
          backgroundOpacity: 1,
          cursorType: TerminalCursorType.block,
        ),
      ),
    );
  }
}

/// Derive an xterm [TerminalTheme] from our surface tokens.
///
/// Foreground / background pull from the editor tokens so the terminal
/// visually matches the rest of the IDE. The 16-color ANSI palette is
/// chosen to read well on our current two bundled themes
/// (summer-night + whatever else ships); a future pass lets themes
/// override the palette directly in their YAML.
TerminalTheme _buildTheme(SurfaceTokens t) {
  // Selection tint derived from the focus accent at 40% alpha — no
  // dedicated token yet; revisit when the theme layer grows an
  // editor.selection.* token family.
  final selection = t.globalFocus.withAlpha(0x66);
  return TerminalTheme(
    cursor: t.globalForeground,
    selection: selection,
    foreground: t.globalForeground,
    background: t.panelBackground,
    // ANSI palette — reasonable defaults tuned for dark themes. The
    // bright variants are the same hue with higher luminance.
    black: const Color(0xFF1b1d23),
    red: const Color(0xFFe06c75),
    green: const Color(0xFF98c379),
    yellow: const Color(0xFFe5c07b),
    blue: const Color(0xFF61afef),
    magenta: const Color(0xFFc678dd),
    cyan: const Color(0xFF56b6c2),
    white: const Color(0xFFabb2bf),
    brightBlack: const Color(0xFF5c6370),
    brightRed: const Color(0xFFff7b85),
    brightGreen: const Color(0xFFabd486),
    brightYellow: const Color(0xFFffd89a),
    brightBlue: const Color(0xFF82c5ff),
    brightMagenta: const Color(0xFFdb8fe4),
    brightCyan: const Color(0xFF6fcbd6),
    brightWhite: const Color(0xFFffffff),
    searchHitBackground: const Color(0xFFffeb8c),
    searchHitBackgroundCurrent: const Color(0xFFffd54a),
    searchHitForeground: const Color(0xFF1b1d23),
  );
}
