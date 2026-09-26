/// The session WebSocket's pass-through (D-117): what the browser sends goes
/// to the workspace host's socket and what the host sends comes back, byte
/// for byte, with nothing parsed on the way.
library;

import 'dart:async';
import 'dart:io';

final class SessionPipe {
  SessionPipe._(this._browser, this._host);

  /// Bridges [browser] and [host] until either side ends. Each binary message
  /// from the browser is written to the host as it is, and whatever the host
  /// sends goes back in binary messages. The pipe carries bytes only, so a
  /// text message ends the session.
  factory SessionPipe.open(WebSocket browser, Socket host) {
    final pipe = SessionPipe._(browser, host);
    pipe.done = pipe._run();
    return pipe;
  }

  final WebSocket _browser;
  final Socket _host;

  /// Completes once both sides are closed. It never completes with an error.
  late final Future<void> done;

  int _code = WebSocketStatus.goingAway;
  String _reason = 'The workspace host ended the session.';

  /// Ends the session from the broker's side, telling the browser [code] and
  /// [reason]. Anything the browser sends after this goes nowhere.
  void end(int code, String reason) {
    _code = code;
    _reason = reason;
    _host.destroy();
  }

  Future<void> _run() async {
    // A write to a host that has gone fails through `done`. The session ends
    // either way, so that is no error of its own.
    unawaited(_host.done.then<void>((_) {}, onError: (Object _) {}));
    // When the browser closes, drops, or breaks the protocol, dart:io closes
    // the WebSocket itself and ends this stream without an error. That ends
    // the host's side below, through addStream.
    _browser.listen((message) {
      if (message is List<int>) {
        _host.add(message);
      } else {
        end(WebSocketStatus.unsupportedData, 'The session carries binary messages only.');
      }
    });
    try {
      await _browser.addStream(_host);
    } on Object {
      end(WebSocketStatus.internalServerError, 'The connection to the workspace host failed.');
    }
    _host.destroy();
    try {
      await _browser.close(_code, _reason).timeout(const Duration(seconds: 5));
    } on Object {
      // The browser is already gone.
    }
  }
}
