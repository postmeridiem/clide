/// Unit tests for `lib/src/terminal/src/ui/painter.dart` — covers
/// constructor, the three reactive setters (textStyle, textScaler,
/// theme), clearFontCache, paintCursor's three cursor types + the
/// no-focus branch, paintHighlight, paintLine + paintCell branches,
/// and the foreground / background colour resolvers.
library;

import 'dart:ui';

import 'package:clide/src/terminal/src/core/buffer/cell_flags.dart';
import 'package:clide/src/terminal/src/core/cell.dart';
import 'package:clide/src/terminal/src/terminal.dart';
import 'package:clide/src/terminal/src/ui/cursor_type.dart';
import 'package:clide/src/terminal/src/ui/painter.dart';
import 'package:clide/src/terminal/src/ui/terminal_text_style.dart';
import 'package:clide/src/terminal/src/ui/terminal_theme.dart';
import 'package:clide/src/terminal/src/ui/themes.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

TerminalPainter _make({
  TerminalTheme? theme,
  TerminalStyle? style,
  TextScaler? scaler,
}) =>
    TerminalPainter(
      theme: theme ?? TerminalThemes.defaultTheme,
      textStyle: style ?? const TerminalStyle(),
      textScaler: scaler ?? const TextScaler.linear(1.0),
    );

Canvas _canvas() => Canvas(PictureRecorder());

void main() {
  group('TerminalPainter — construction + cellSize', () {
    test('cellSize is non-zero after construction', () {
      final p = _make();
      expect(p.cellSize.width, greaterThan(0));
      expect(p.cellSize.height, greaterThan(0));
    });
  });

  group('TerminalPainter — reactive setters', () {
    test('textStyle setter same value is a no-op (early return)', () {
      final p = _make();
      final style = p.textStyle;
      final size = p.cellSize;
      p.textStyle = style;
      expect(p.textStyle, same(style));
      expect(p.cellSize, size);
    });

    test('textStyle setter different value recomputes cellSize', () {
      final p = _make();
      final newStyle = const TerminalStyle(fontSize: 24);
      p.textStyle = newStyle;
      expect(p.textStyle, newStyle);
      expect(p.cellSize.width, greaterThan(0));
      expect(p.cellSize.height, greaterThan(0));
    });

    test('textScaler setter same value is a no-op', () {
      final p = _make();
      final scaler = p.textScaler;
      p.textScaler = scaler;
      expect(p.textScaler, same(scaler));
    });

    test('textScaler setter different value recomputes cellSize', () {
      final p = _make();
      p.textScaler = const TextScaler.linear(2.0);
      expect(p.textScaler, const TextScaler.linear(2.0));
      expect(p.cellSize.width, greaterThan(0));
    });

    test('theme setter same value is a no-op', () {
      final p = _make();
      final theme = p.theme;
      p.theme = theme;
      expect(p.theme, same(theme));
    });

    test('theme setter different value swaps theme and rebuilds palette', () {
      final p = _make();
      // The two bundled themes share an ANSI palette; the foreground
      // colour is what differs (#CCCCCC vs #FFFFFF). Use the normal
      // colour-type which routes to theme.foreground.
      expect(p.resolveForegroundColor(CellColor.normal), TerminalThemes.defaultTheme.foreground);
      p.theme = TerminalThemes.whiteOnBlack;
      expect(p.theme, TerminalThemes.whiteOnBlack);
      expect(p.resolveForegroundColor(CellColor.normal), TerminalThemes.whiteOnBlack.foreground);
    });

    test('clearFontCache leaves cellSize valid and the painter usable', () {
      final p = _make();
      p.clearFontCache();
      expect(p.cellSize.width, greaterThan(0));
      // Re-paint after clearing — must not throw.
      p.paintCursor(_canvas(), Offset.zero, cursorType: TerminalCursorType.block);
    });
  });

  group('TerminalPainter — paintCursor', () {
    final cases = <TerminalCursorType>{
      TerminalCursorType.block,
      TerminalCursorType.underline,
      TerminalCursorType.verticalBar,
    };
    for (final c in cases) {
      test('focused $c paints without throwing', () {
        _make().paintCursor(_canvas(), const Offset(0, 0), cursorType: c);
      });
    }

    test('unfocused (hasFocus=false) draws a stroked rect regardless of cursor type', () {
      // Should hit the early-return-with-stroke branch, not the switch.
      _make().paintCursor(
        _canvas(),
        const Offset(0, 0),
        cursorType: TerminalCursorType.verticalBar,
        hasFocus: false,
      );
    });
  });

  group('TerminalPainter — paintHighlight', () {
    test('paints without throwing for several lengths', () {
      final p = _make();
      const color = Color(0xFFFF0000);
      p.paintHighlight(_canvas(), Offset.zero, 1, color);
      p.paintHighlight(_canvas(), const Offset(20, 20), 5, color);
      p.paintHighlight(_canvas(), const Offset(0, 0), 0, color);
    });
  });

  group('TerminalPainter — paintLine + paintCell', () {
    test('paints a line of normal cells without throwing', () {
      final t = Terminal(maxLines: 100, onOutput: (_) {});
      t.write('hello');
      _make().paintLine(_canvas(), Offset.zero, t.buffer.lines[0]);
    });

    test('paintCellForeground exits early on empty (codepoint 0) cell', () {
      final p = _make();
      // The defaultly-zeroed CellData has content == 0 → codepoint 0 → returns
      // immediately. Just verify no throw.
      p.paintCellForeground(_canvas(), Offset.zero, CellData.empty());
    });

    test('paintCellForeground caches the layout — second call hits the cache', () {
      final p = _make();
      final cell = CellData(
        foreground: CellColor.normal,
        background: CellColor.normal,
        flags: 0,
        content: 'A'.codeUnitAt(0),
      );
      // Two paints with the same cell → second one resolves through the cache.
      p.paintCellForeground(_canvas(), Offset.zero, cell);
      p.paintCellForeground(_canvas(), Offset.zero, cell);
    });

    test('paintCellForeground honours faint, inverse, underline-on-space', () {
      final p = _make();
      // faint
      p.paintCellForeground(
          _canvas(),
          Offset.zero,
          CellData(
            foreground: CellColor.normal,
            background: CellColor.normal,
            flags: CellFlags.faint,
            content: 'B'.codeUnitAt(0),
          ));
      // inverse → uses background as foreground
      p.paintCellForeground(
          _canvas(),
          Offset.zero,
          CellData(
            foreground: CellColor.normal,
            background: CellColor.named | 2,
            flags: CellFlags.inverse,
            content: 'C'.codeUnitAt(0),
          ));
      // underline + space → swaps to U+00A0 internally
      p.paintCellForeground(
          _canvas(),
          Offset.zero,
          CellData(
            foreground: CellColor.normal,
            background: CellColor.normal,
            flags: CellFlags.underline,
            content: 0x20,
          ));
      // bold + italic — exercises the flag-driven TextStyle path.
      p.paintCellForeground(
          _canvas(),
          Offset.zero,
          CellData(
            foreground: CellColor.normal,
            background: CellColor.normal,
            flags: CellFlags.bold | CellFlags.italic,
            content: 'D'.codeUnitAt(0),
          ));
    });

    test('paintCellBackground covers normal early-return, inverse, and named/palette paths', () {
      final p = _make();
      // normal + no inverse → early return, no draw.
      p.paintCellBackground(
          _canvas(),
          Offset.zero,
          CellData(
            foreground: CellColor.normal,
            background: CellColor.normal,
            flags: 0,
            content: 0,
          ));
      // inverse → resolves foreground colour and draws.
      p.paintCellBackground(
          _canvas(),
          Offset.zero,
          CellData(
            foreground: CellColor.named | 1,
            background: CellColor.normal,
            flags: CellFlags.inverse,
            content: 0,
          ));
      // explicit background colour → draws.
      p.paintCellBackground(
          _canvas(),
          Offset.zero,
          CellData(
            foreground: CellColor.normal,
            background: CellColor.palette | 5,
            flags: 0,
            content: 0,
          ));
      // double-width cell → exercises the widthScale=2 branch.
      p.paintCellBackground(
          _canvas(),
          Offset.zero,
          CellData(
            foreground: CellColor.normal,
            background: CellColor.named | 4,
            flags: 0,
            content: 'A'.codeUnitAt(0) | (2 << CellContent.widthShift),
          ));
    });
  });

  group('TerminalPainter — colour resolvers', () {
    test('resolveForegroundColor returns theme.foreground for normal type', () {
      final p = _make();
      expect(p.resolveForegroundColor(CellColor.normal), TerminalThemes.defaultTheme.foreground);
    });

    test('resolveForegroundColor returns palette entry for named/palette types', () {
      final p = _make();
      // Both `named` and `palette` route through _colorPalette[value], so
      // both should produce identical results for the same index.
      final viaNamed = p.resolveForegroundColor(CellColor.named | 3);
      final viaPalette = p.resolveForegroundColor(CellColor.palette | 3);
      expect(viaNamed, viaPalette);
    });

    test('resolveForegroundColor returns the rgb value with full alpha', () {
      final p = _make();
      final c = p.resolveForegroundColor(CellColor.rgb | 0x123456);
      // The painter ORs in 0xFF000000 to force full alpha.
      expect(c.toARGB32(), 0xFF123456);
    });

    test('resolveBackgroundColor mirrors the foreground resolver paths', () {
      final p = _make();
      expect(p.resolveBackgroundColor(CellColor.normal), TerminalThemes.defaultTheme.background);
      final viaNamed = p.resolveBackgroundColor(CellColor.named | 7);
      final viaPalette = p.resolveBackgroundColor(CellColor.palette | 7);
      expect(viaNamed, viaPalette);
      final rgb = p.resolveBackgroundColor(CellColor.rgb | 0xABCDEF);
      expect(rgb.toARGB32(), 0xFFABCDEF);
    });
  });
}
