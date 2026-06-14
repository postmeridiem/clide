// Based on xterm.dart v4.0.0 by xuty (MIT). See LICENSE in this directory.

import 'package:clide/src/terminal/src/core/color.dart';
import 'package:clide/src/terminal/src/core/mouse/mode.dart';
import 'package:clide/src/terminal/src/core/escape/handler.dart';
import 'package:clide/src/terminal/src/utils/ascii.dart';
import 'package:clide/src/terminal/src/utils/byte_consumer.dart';
import 'package:clide/src/terminal/src/utils/char_code.dart';
import 'package:clide/src/terminal/src/utils/lookup_table.dart';

part 'csi_handlers.dart';
part 'mode_handlers.dart';
part 'osc_handlers.dart';
part 'sgr_handlers.dart';

/// Shared parser state the handler mixins operate on: the escape
/// handler sink, the byte queue, token bookkeeping, and the reusable
/// CSI scratch object (zero-allocation design — see [EscapeParser]).
abstract class _EscapeParserBase {
  _EscapeParserBase(this.handler);

  final EscapeHandler handler;

  final _queue = ByteConsumer();

  /// Start of sequence or character being processed. Useful for debugging.
  var tokenBegin = 0;

  /// End of sequence or character being processed. Useful for debugging.
  int get tokenEnd => _queue.totalConsumed;

  /// The last parsed [_Csi]. This is a mutable singletion by design to reduce
  /// object allocations.
  final _csi = _Csi(finalByte: 0, params: []);
}

/// [EscapeParser] translates control characters and escape sequences into
/// function calls that the terminal can handle.
///
/// Design goals:
///  * Zero object allocation during processing.
///  * No internal state. Same input will always produce same output.
///
/// The handler groups live as mixins in this library's part files
/// (csi/sgr/mode/osc handlers, T-123); this core owns the byte queue,
/// the dispatch tables, and the ESC/CSI consumers.
class EscapeParser extends _EscapeParserBase with _CsiHandlers, _ModeHandlers, _OscHandlers, _SgrHandlers {
  EscapeParser(super.handler);

  void write(String chunk) {
    _queue.unrefConsumedBlocks();
    _queue.add(chunk);
    _process();
  }

  void _process() {
    while (_queue.isNotEmpty) {
      tokenBegin = _queue.totalConsumed;
      final char = _queue.consume();

      if (char == Ascii.ESC) {
        final processed = _processEscape();
        if (!processed) {
          _queue.rollback(tokenEnd - tokenBegin);
          return;
        }
      } else {
        _processChar(char);
      }
    }
  }

  void _processChar(int char) {
    if (char > _sbcHandlers.maxIndex) {
      handler.writeChar(char);
      return;
    }

    final sbcHandler = _sbcHandlers[char];
    if (sbcHandler == null) {
      handler.unkownEscape(char);
      return;
    }

    sbcHandler();
  }

  /// Processes a sequence of characters that starts with an escape character.
  /// Returns [true] if the sequence was processed, [false] if it was not.
  bool _processEscape() {
    if (_queue.isEmpty) return false;

    final escapeChar = _queue.consume();
    final escapeHandler = _escHandlers[escapeChar];

    if (escapeHandler == null) {
      handler.unkownEscape(escapeChar);
      return true;
    }

    return escapeHandler();
  }

  late final _sbcHandlers = FastLookupTable<_SbcHandler>({
    0x07: handler.bell,
    0x08: handler.backspaceReturn,
    0x09: handler.tab,
    0x0a: handler.lineFeed,
    0x0b: handler.lineFeed,
    0x0c: handler.lineFeed,
    0x0d: handler.carriageReturn,
    0x0e: handler.shiftOut,
    0x0f: handler.shiftIn,
  });

  late final _escHandlers = FastLookupTable<_EscHandler>({
    '['.charCode: _escHandleCSI,
    ']'.charCode: _escHandleOSC,
    '7'.charCode: _escHandleSaveCursor,
    '8'.charCode: _escHandleRestoreCursor,
    'D'.charCode: _escHandleIndex,
    'E'.charCode: _escHandleNextLine,
    'H'.charCode: _escHandleTabSet,
    'M'.charCode: _escHandleReverseIndex,
    // 'P'.charCode: _unsupportedHandler, // Sixel
    // 'c'.charCode: _unsupportedHandler,
    // '#'.charCode: _unsupportedHandler,
    '('.charCode: _escHandleDesignateCharset0, // SCS — G0
    ')'.charCode: _escHandleDesignateCharset1, // SCS — G1
    // G2 (`ESC *`) and G3 (`ESC +`) charset designators are VT220+
    // sequences we don't honour — no consumer in clide selects past
    // G0/G1. Sequences pass through as no-ops (one trailing byte is
    // consumed by the default parser).
    '>'.charCode: _escHandleResetAppKeypadMode,
    '='.charCode: _escHandleSetAppKeypadMode,
  });

  /// `ESC 7` Save Cursor (DECSC)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_a7/
  bool _escHandleSaveCursor() {
    handler.saveCursor();
    return true;
  }

  /// `ESC 8` Restore Cursor (DECRC)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_a8/
  bool _escHandleRestoreCursor() {
    handler.restoreCursor();
    return true;
  }

  /// `ESC D` Index (IND)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_cd/
  bool _escHandleIndex() {
    handler.index();
    return true;
  }

  /// `ESC E` Next Line (NEL)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_ce/
  bool _escHandleNextLine() {
    handler.nextLine();
    return true;
  }

  /// `ESC H` Horizontal Tab Set (HTS)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_ch/
  bool _escHandleTabSet() {
    handler.setTapStop();
    return true;
  }

  /// `ESC M` Reverse Index (RI)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_cm/
  bool _escHandleReverseIndex() {
    handler.reverseIndex();
    return true;
  }

  bool _escHandleDesignateCharset0() {
    if (_queue.isEmpty) return false;
    int name = _queue.consume();
    handler.designateCharset(0, name);
    return true;
  }

  bool _escHandleDesignateCharset1() {
    if (_queue.isEmpty) return false;
    int name = _queue.consume();
    handler.designateCharset(1, name);
    return true;
  }

  /// `ESC =` Set Application Keypad Mode (DECKPAM)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_x3d_equals/
  bool _escHandleSetAppKeypadMode() {
    handler.setAppKeypadMode(true);
    return true;
  }

  /// `ESC >` Reset Application Keypad Mode (DECKPNM)
  ///
  /// https://terminalguide.namepad.de/seq/a_esc_x3c_greater_than/
  bool _escHandleResetAppKeypadMode() {
    handler.setAppKeypadMode(false);
    return true;
  }

  bool _escHandleCSI() {
    final consumed = _consumeCsi();
    if (!consumed) return false;

    // An intermediate byte changes the meaning of the final byte
    // (`CSI 5 SP @` is scroll-left, not insert-blank). None of the
    // intermediate forms are implemented, so report them as unknown
    // rather than mis-dispatching on the bare final byte.
    final csiHandler = _csi.intermediates.isEmpty ? _csiHandlers[_csi.finalByte] : null;

    if (csiHandler == null) {
      handler.unknownCSI(_csi.finalByte);
    } else {
      csiHandler();
    }

    return true;
  }

  /// Parse a CSI from the head of the queue. Return false if the CSI isn't
  /// complete. After a CSI is successfully parsed, [_csi] is updated.
  bool _consumeCsi() {
    if (_queue.isEmpty) {
      return false;
    }

    _csi.params.clear();
    _csi.subParam.clear();
    _csi.intermediates.clear();

    // test whether the csi is a `CSI ? Ps ...` or `CSI Ps ...`
    final prefix = _queue.peek();
    if (prefix >= Ascii.colon && prefix <= Ascii.questionMark) {
      _csi.prefix = prefix;
      _queue.consume();
    } else {
      _csi.prefix = null;
    }

    var param = 0;
    var hasParam = false;
    // Whether the value being accumulated was attached to its predecessor
    // with a colon (ECMA-48 sub-parameter separator, ITU T.416 SGR colors).
    // Before T-369 colons were silently dropped mid-sequence, fusing
    // `38:2:255:0:0` into one bogus parameter.
    var linkedToPrev = false;
    while (true) {
      // The sequence isn't completed, just ignore it.
      if (_queue.isEmpty) {
        return false;
      }

      final char = _queue.consume();

      if (char == Ascii.semicolon) {
        if (hasParam) {
          _csi.params.add(param);
          _csi.subParam.add(linkedToPrev);
        }
        param = 0;
        linkedToPrev = false;
        continue;
      }

      if (char == Ascii.colon) {
        // Push the current value even when empty — `38:2::r:g:b` carries an
        // empty colorspace slot that must keep its position in the group.
        _csi.params.add(hasParam ? param : 0);
        _csi.subParam.add(linkedToPrev);
        hasParam = true;
        param = 0;
        linkedToPrev = true;
        continue;
      }

      if (char >= Ascii.num0 && char <= Ascii.num9) {
        hasParam = true;
        param *= 10;
        param += char - Ascii.num0;
        continue;
      }

      if (char >= Ascii.space && char <= Ascii.slash) {
        _csi.intermediates.add(char);
        continue;
      }

      if (char > Ascii.NULL && char < Ascii.num0) {
        // Other C0 controls embedded in a CSI: ignore, as before.
        continue;
      }

      if (char >= Ascii.atSign && char <= Ascii.tilde) {
        if (hasParam) {
          _csi.params.add(param);
          _csi.subParam.add(linkedToPrev);
        }

        _csi.finalByte = char;
        return true;
      }
    }
  }

  late final _csiHandlers = FastLookupTable<_CsiHandler>({
    // 'a'.codeUnitAt(0): _csiHandleCursorHorizontalRelative,
    'b'.codeUnitAt(0): _csiHandleRepeatPreviousCharacter,
    'c'.codeUnitAt(0): _csiHandleSendDeviceAttributes,
    'd'.codeUnitAt(0): _csiHandleLinePositionAbsolute,
    'f'.codeUnitAt(0): _csiHandleCursorPosition,
    'g'.codeUnitAt(0): _csiHandelClearTabStop,
    'h'.codeUnitAt(0): _csiHandleMode,
    'l'.codeUnitAt(0): _csiHandleMode,
    'm'.codeUnitAt(0): _csiHandleSgr,
    'n'.codeUnitAt(0): _csiHandleDeviceStatusReport,
    'r'.codeUnitAt(0): _csiHandleSetMargins,
    't'.codeUnitAt(0): _csiWindowManipulation,
    'A'.codeUnitAt(0): _csiHandleCursorUp,
    'B'.codeUnitAt(0): _csiHandleCursorDown,
    'C'.codeUnitAt(0): _csiHandleCursorForward,
    'D'.codeUnitAt(0): _csiHandleCursorBackward,
    'E'.codeUnitAt(0): _csiHandleCursorNextLine,
    'F'.codeUnitAt(0): _csiHandleCursorPrecedingLine,
    'G'.codeUnitAt(0): _csiHandleCursorHorizontalAbsolute,
    'H'.codeUnitAt(0): _csiHandleCursorPosition,
    'J'.codeUnitAt(0): _csiHandleEraseDisplay,
    'K'.codeUnitAt(0): _csiHandleEraseLine,
    'L'.codeUnitAt(0): _csiHandleInsertLines,
    'M'.codeUnitAt(0): _csiHandleDeleteLines,
    'P'.codeUnitAt(0): _csiHandleDelete,
    'S'.codeUnitAt(0): _csiHandleScrollUp,
    'T'.codeUnitAt(0): _csiHandleScrollDown,
    'X'.codeUnitAt(0): _csiHandleEraseCharacters,
    '@'.codeUnitAt(0): _csiHandleInsertBlankCharacters,
  });
}

class _Csi {
  _Csi({required this.params, required this.finalByte});

  int? prefix;

  List<int> params;

  /// Parallel to [params]: true when that parameter was attached to its
  /// predecessor with a colon (ECMA-48 sub-parameter, ITU T.416 — T-369).
  final List<bool> subParam = [];

  int finalByte;

  /// Intermediate bytes (0x20–0x2f) between the parameters and the final
  /// byte — `SP` in `CSI Ps SP q` (DECSCUSR), `!` in `CSI ! p` (DECSTR).
  /// They change the meaning of the final byte, so dispatch must not fall
  /// through to the bare-final handler when any are present.
  final List<int> intermediates = [];

  @override
  String toString() {
    return params.join(';') + String.fromCharCode(finalByte);
  }
}

/// Function that handles a sequence of characters that starts with an escape.
/// Returns [true] if the sequence was processed, [false] if it was not.
typedef _EscHandler = bool Function();

typedef _SbcHandler = void Function();

typedef _CsiHandler = void Function();
