// Based on xterm.dart v4.0.0 by xuty (MIT). See LICENSE in this directory.

// OSC string parsing + dispatch (title / icon name / private
// pass-through), BEL or ST terminated. Split out of parser.dart
// (T-123).

part of 'parser.dart';

mixin _OscHandlers on _EscapeParserBase {
  /// Parse a OSC sequence from the queue. Returns true if a sequence was
  /// found and handled.
  bool _escHandleOSC() {
    final consumed = _consumeOsc();
    if (!consumed) {
      return false;
    }

    if (_osc.isEmpty) {
      return true;
    }

    // Common OSCs
    if (_osc.length >= 2) {
      final ps = _osc[0];
      final pt = _osc[1];

      switch (ps) {
        case '0':
          handler.setTitle(pt);
          handler.setIconName(pt);
          return true;
        case '1':
          handler.setIconName(pt);
          return true;
        case '2':
          handler.setTitle(pt);
          return true;
      }
    }

    // Private extensions
    handler.unknownOSC(_osc[0], _osc.sublist(1));

    return true;
  }

  final _osc = <String>[];

  bool _consumeOsc() {
    _osc.clear();
    final param = StringBuffer();

    while (true) {
      if (_queue.isEmpty) {
        return false;
      }

      final char = _queue.consume();

      // OSC terminates with BEL
      if (char == Ascii.BEL) {
        _osc.add(param.toString());
        return true;
      }

      /// OSC terminates with ST
      if (char == Ascii.ESC) {
        if (_queue.isEmpty) {
          return false;
        }

        if (_queue.consume() == Ascii.backslash) {
          _osc.add(param.toString());
        }

        return true;
      }

      /// Parse next parameter
      if (char == Ascii.semicolon) {
        _osc.add(param.toString());
        param.clear();
        continue;
      }

      param.writeCharCode(char);
    }
  }
}
