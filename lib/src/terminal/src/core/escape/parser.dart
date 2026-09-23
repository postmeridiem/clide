// Based on xterm.dart v4.0.0 by xuty (MIT). See LICENSE in this directory.

import 'package:clide/src/terminal/src/core/color.dart';
import 'package:clide/src/terminal/src/core/cursor.dart';
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

  /// Input being discarded as it streams in: an ignored control string
  /// (DCS/SOS/PM/APC), an OSC past [_kMaxOscLength], or a CSI past
  /// [_kMaxCsiLength]. The one piece of state the parser carries across
  /// writes — without it the body of a string split over two writes, or
  /// the tail of a dropped one, would print as text (T-637, T-612).
  _Skip _skip = _Skip.none;
}

enum _Skip {
  none,

  /// Until ST (`ESC \`), CAN or SUB. Another ESC ends it and starts the
  /// next sequence.
  string,

  /// As [string], but BEL terminates too (OSC).
  stringOrBel,

  /// Until a CSI final byte (0x40–0x7E), CAN, SUB or ESC.
  csi,
}

/// Upper bound on a CSI numeric parameter. Real sequences stay far below;
/// an unbounded accumulator overflowed into garbage counts (T-612).
const int _kMaxCsiParam = 65535;

/// Parameters kept per CSI; extras are ignored, as in xterm (30).
const int _kMaxCsiParams = 32;

/// Bytes a CSI may run to before it is dropped. Keeps an unterminated
/// sequence from being re-scanned from its start on every write (T-612).
const int _kMaxCsiLength = 4096;

/// Bytes an OSC may run to before it is dropped (T-612). Clide's OSCs —
/// titles, cwd, hyperlinks — are far smaller.
const int _kMaxOscLength = 65536;

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
      if (_skip != _Skip.none) {
        if (!_consumeSkipped()) return;
        continue;
      }
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

  /// Discard input per [_skip] until its terminator. Returns false when the
  /// queue ran dry first (the skip carries over to the next write).
  bool _consumeSkipped() {
    while (_queue.isNotEmpty) {
      final char = _queue.consume();
      if (char == Ascii.CAN || char == Ascii.SUB) {
        _skip = _Skip.none;
        return true;
      }
      if (char == Ascii.ESC) {
        if (_skip != _Skip.csi) {
          if (_queue.isEmpty) {
            // Might be the start of ST; decide when the next byte arrives.
            _queue.rollback(1);
            return false;
          }
          if (_queue.peek() == Ascii.backslash) {
            _queue.consume();
            _skip = _Skip.none;
            return true;
          }
        }
        // Any other ESC ends the skipped input and begins a new sequence.
        _queue.rollback(1);
        _skip = _Skip.none;
        return true;
      }
      if (_skip == _Skip.stringOrBel && char == Ascii.BEL) {
        _skip = _Skip.none;
        return true;
      }
      if (_skip == _Skip.csi && char >= Ascii.atSign && char <= Ascii.tilde) {
        _skip = _Skip.none;
        return true;
      }
    }
    return false;
  }

  /// `ESC P` (DCS), `ESC X` (SOS), `ESC ^` (PM), `ESC _` (APC): control
  /// strings clide doesn't act on (sixel, DECRQSS, tmux passthrough...).
  /// Their bodies are discarded up to ST, never printed (T-637).
  bool _escHandleIgnoredString() {
    _skip = _Skip.string;
    return true;
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
    'P'.charCode: _escHandleIgnoredString, // DCS (sixel, DECRQSS, ...)
    'X'.charCode: _escHandleIgnoredString, // SOS
    '^'.charCode: _escHandleIgnoredString, // PM
    '_'.charCode: _escHandleIgnoredString, // APC
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
    if (_csiAborted) return true;

    // An intermediate byte changes the meaning of the final byte
    // (`CSI 5 SP @` is scroll-left, not insert-blank), so intermediate
    // forms never fall through to the bare-final table. DECSCUSR is the
    // only one implemented; the rest report as unknown.
    if (_csi.intermediates.isNotEmpty) {
      _dispatchIntermediateCsi();
      return true;
    }

    final csiHandler = _csiHandlers[_csi.finalByte];

    if (csiHandler == null) {
      handler.unknownCSI(_csi.finalByte);
    } else {
      csiHandler();
    }

    return true;
  }

  /// Dispatch a CSI carrying intermediate bytes, keyed on the
  /// (intermediates, final byte) pair. A plain check until a second form
  /// lands (DECSTR, `CSI ! p`, would be next).
  void _dispatchIntermediateCsi() {
    final i = _csi.intermediates;
    if (i.length == 1 && i[0] == Ascii.space && _csi.finalByte == Ascii.q) {
      return _csiHandleSetCursorShape();
    }
    handler.unknownCSI(_csi.finalByte);
  }

  /// Set by [_consumeCsi] when the sequence was cancelled (CAN/SUB, an
  /// interrupting ESC, or over-length) and must not dispatch.
  bool _csiAborted = false;

  /// Add a parameter unless the CSI already holds [_kMaxCsiParams].
  void _addCsiParam(int value, bool linked) {
    if (_csi.params.length >= _kMaxCsiParams) return;
    _csi.params.add(value);
    _csi.subParam.add(linked);
  }

  /// Parse a CSI from the head of the queue. Return false if the CSI isn't
  /// complete. After a CSI is successfully parsed, [_csi] is updated; when it
  /// was cancelled instead, [_csiAborted] is set and nothing should dispatch.
  bool _consumeCsi() {
    if (_queue.isEmpty) {
      return false;
    }

    _csiAborted = false;
    final start = _queue.totalConsumed;
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

      // An endless CSI would be re-scanned from its start on every write;
      // drop it and discard the rest up to its final byte (T-612).
      if (_queue.totalConsumed - start >= _kMaxCsiLength) {
        _skip = _Skip.csi;
        _csiAborted = true;
        return true;
      }

      final char = _queue.consume();

      // CAN / SUB cancel the sequence; an ESC cancels it and starts the
      // next one. Neither dispatches the partial CSI (T-637).
      if (char == Ascii.CAN || char == Ascii.SUB) {
        _csiAborted = true;
        return true;
      }
      if (char == Ascii.ESC) {
        _queue.rollback(1);
        _csiAborted = true;
        return true;
      }

      if (char == Ascii.semicolon) {
        if (hasParam) _addCsiParam(param, linkedToPrev);
        param = 0;
        linkedToPrev = false;
        continue;
      }

      if (char == Ascii.colon) {
        // Push the current value even when empty — `38:2::r:g:b` carries an
        // empty colorspace slot that must keep its position in the group.
        _addCsiParam(hasParam ? param : 0, linkedToPrev);
        hasParam = true;
        param = 0;
        linkedToPrev = true;
        continue;
      }

      if (char >= Ascii.num0 && char <= Ascii.num9) {
        hasParam = true;
        // Clamped: an unbounded accumulator overflowed int64 (T-612).
        param = param * 10 + (char - Ascii.num0);
        if (param > _kMaxCsiParam) param = _kMaxCsiParam;
        continue;
      }

      if (char >= Ascii.space && char <= Ascii.slash) {
        if (_csi.intermediates.length < _kMaxCsiParams) _csi.intermediates.add(char);
        continue;
      }

      if (char > Ascii.NULL && char < Ascii.num0) {
        // Other C0 controls embedded in a CSI: ignore, as before.
        continue;
      }

      if (char >= Ascii.atSign && char <= Ascii.tilde) {
        if (hasParam) _addCsiParam(param, linkedToPrev);

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
