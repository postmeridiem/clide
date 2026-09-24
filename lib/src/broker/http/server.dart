/// The broker's HTTP side (D-117, D-118): a server on a unix socket that only
/// Caddy reaches. It answers Caddy's forward-auth check for every request
/// outside `/auth/`, and serves the sign-in and sign-out pages.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../auth/login_page.dart';
import '../auth/secrets.dart';
import '../auth/sessions.dart';
import '../environment.dart';
import '../serve_config.dart';
import '../store/broker_store.dart';

final class BrokerServer {
  BrokerServer._(this._server, this.path, this._store, this._config, this._sessions, this._failureDelay, this._log) {
    _server.listen(_handle);
    _sweeper = Timer.periodic(const Duration(hours: 1), (_) => unawaited(_sweep()));
    unawaited(_sweep());
  }

  /// Serves on a unix socket at [path], which only this user can use (D-71):
  /// the socket is 0600 and a directory the broker creates is 0700. A socket
  /// left behind by a broker that is gone is replaced; one a running broker
  /// still answers on is not.
  ///
  /// [failureDelay] slows every refused sign-in down. [log] receives a line
  /// per sign-in, sign-out and failure; it never receives a secret.
  static Future<BrokerServer> bind(
    String path, {
    required BrokerStore store,
    required ServeConfig config,
    Duration failureDelay = const Duration(seconds: 1),
    DateTime Function()? clock,
    void Function(String line)? log,
  }) async {
    final directory = File(path).parent;
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
      await _chmod(directory.path, '700');
    }
    if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound) {
      try {
        final probe = await Socket.connect(InternetAddress(path, type: InternetAddressType.unix), 0).timeout(const Duration(seconds: 1));
        probe.destroy();
        throw BrokerConfigException('Another broker is serving $path.');
      } on SocketException {
        File(path).deleteSync();
      } on TimeoutException {
        File(path).deleteSync();
      }
    }
    final server = await HttpServer.bind(InternetAddress(path, type: InternetAddressType.unix), 0);
    try {
      await _chmod(path, '600');
    } catch (_) {
      await server.close(force: true);
      rethrow;
    }
    server
      ..idleTimeout = const Duration(seconds: 30)
      ..autoCompress = false
      ..serverHeader = null
      ..defaultResponseHeaders.clear();
    final sessions = Sessions(store, lifetime: config.sessionLifetime, clock: clock);
    return BrokerServer._(server, path, store, config, sessions, failureDelay, log ?? (_) {});
  }

  final HttpServer _server;
  final String path;
  final BrokerStore _store;
  final ServeConfig _config;
  final Sessions _sessions;
  final Duration _failureDelay;
  final void Function(String line) _log;
  late final Timer _sweeper;

  Future<void> close() async {
    _sweeper.cancel();
    await _server.close(force: true);
    if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound) File(path).deleteSync();
  }

  Future<void> _sweep() async {
    try {
      await _store.sweep();
    } catch (e) {
      // A timer has no caller to report to, so a failure is logged here.
      _log('could not sweep expired sessions: ${e.runtimeType}');
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('x-content-type-options', 'nosniff')
      ..set('referrer-policy', 'no-referrer');
    try {
      switch ((request.method, request.uri.path)) {
        case ('GET', '/auth/verify'):
          await _verify(request);
        case ('GET', '/auth/login'):
          _signInPage(request);
        case ('POST', '/auth/login'):
          await _signIn(request);
        case ('POST', '/auth/logout'):
          await _signOut(request);
        case (_, '/auth/verify' || '/auth/login' || '/auth/logout'):
          _answer(response, 405, 'That method is not allowed here.');
        default:
          _answer(response, 404, 'Not found.');
      }
    } catch (e) {
      // Whatever fails, a store or a bug, Caddy still gets an answer.
      _log('request failed: ${e.runtimeType}');
      try {
        _answer(response, 503, 'The broker cannot reach its store.');
      } on StateError {
        // The answer had already started.
      }
    }
    await response.close();
  }

  /// Caddy's forward-auth check. A 2xx lets the request through with
  /// `X-Clide-User`; anything else goes back to the browser as it is.
  Future<void> _verify(HttpRequest request) async {
    final uri = request.headers.value('x-forwarded-uri') ?? '/';
    final session = await _sessions.find(request.headers.value(HttpHeaders.cookieHeader));
    if (session != null) {
      final owner = pathUser(uri);
      if (owner != null && owner != session.user) {
        _answer(request.response, 403, 'This path belongs to another user.');
        return;
      }
      request.response.headers.set('x-clide-user', '${session.user}');
      _answer(request.response, 200, '');
      return;
    }
    if (_isNavigation(request)) {
      _redirect(request.response, '/auth/login?next=${Uri.encodeQueryComponent(safeNext(uri))}', status: HttpStatus.found);
    } else {
      _answer(request.response, 401, 'Sign in first.');
    }
  }

  void _signInPage(HttpRequest request) {
    final query = request.uri.queryParameters;
    request.response.headers
      ..set('content-security-policy', loginPageCsp)
      ..contentType = ContentType.html;
    request.response.write(loginPage(next: safeNext(query['next']), failed: query['error'] == '1'));
  }

  Future<void> _signIn(HttpRequest request) async {
    if (!_fromOwnOrigin(request)) {
      _answer(request.response, 403, 'A sign-in must come from ${_config.publicOrigin}.');
      return;
    }
    final form = await _form(request);
    if (form == null) return;
    final next = safeNext(form['next']);
    final value = form['token'] ?? '';
    final who = looksLikeSecret(value) ? await _identify(value) : null;
    if (who == null) {
      _log('a sign-in was refused');
      await Future<void>.delayed(_failureDelay);
      _redirect(request.response, '/auth/login?error=1&next=${Uri.encodeQueryComponent(next)}');
      return;
    }
    final (user, via) = who;
    request.response.headers.add(HttpHeaders.setCookieHeader, await _sessions.start(user, via: via));
    _log('user $user signed in by $via');
    _redirect(request.response, next);
  }

  /// Whose token or single-use link [value] is, and which it was.
  Future<(int, String)?> _identify(String value) async {
    final hash = secretHash(value);
    if (_config.mode == SigninMode.token) {
      final stored = await _store.tokenHash(0);
      if (stored != null && sameHash(hash, stored)) return (0, 'token');
    }
    final user = await _store.useSigninLink(hash);
    return user == null ? null : (user, 'link');
  }

  Future<void> _signOut(HttpRequest request) async {
    if (!_fromOwnOrigin(request)) {
      _answer(request.response, 403, 'A sign-out must come from ${_config.publicOrigin}.');
      return;
    }
    await _sessions.end(request.headers.value(HttpHeaders.cookieHeader));
    request.response.headers.add(HttpHeaders.setCookieHeader, Sessions.clearCookie);
    _log('a session was signed out');
    _redirect(request.response, '/auth/login');
  }

  /// A browser sends `Origin` with every POST. One from anywhere else is a
  /// cross-site request, and one without it is not a browser's form.
  bool _fromOwnOrigin(HttpRequest request) => request.headers.value('origin') == _config.publicOrigin;

  /// The posted form, or null once the request has been answered with why
  /// it is not one.
  Future<Map<String, String>?> _form(HttpRequest request) async {
    if (request.headers.contentType?.mimeType != 'application/x-www-form-urlencoded') {
      _answer(request.response, 415, 'Send a form.');
      return null;
    }
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > 4096) {
        _answer(request.response, 413, 'That form is too large.');
        return null;
      }
    }
    try {
      return Uri.splitQueryString(utf8.decode(bytes));
    } on Object catch (e) {
      // Bad UTF-8 throws a FormatException, a bad percent-escape an
      // ArgumentError; either way the form is unreadable, not a failure of
      // the broker.
      if (e is! FormatException && e is! ArgumentError) rethrow;
      _answer(request.response, 400, 'That form cannot be read.');
      return null;
    }
  }

  static void _answer(HttpResponse response, int status, String text) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.text
      ..write(text);
  }

  static void _redirect(HttpResponse response, String location, {int status = HttpStatus.seeOther}) {
    response
      ..statusCode = status
      ..headers.set(HttpHeaders.locationHeader, location);
  }

  static bool _isNavigation(HttpRequest request) {
    final mode = request.headers.value('sec-fetch-mode');
    if (mode != null) return mode == 'navigate';
    final method = request.headers.value('x-forwarded-method') ?? 'GET';
    return method == 'GET' && (request.headers.value(HttpHeaders.acceptHeader) ?? '').contains('text/html');
  }
}

/// The user a path belongs to: `N` for `/u/N/…`, -1 for a `/u/` path that
/// names no user in the one spelling accepted, and null for a path outside
/// `/u/`, which any signed-in user may reach.
int? pathUser(String uri) {
  final path = uri.split('?').first;
  if (!path.startsWith('/u/')) return null;
  final match = _userPath.firstMatch(path);
  return match == null ? -1 : int.parse(match[1]!);
}

final _userPath = RegExp(r'^/u/(0|[1-9][0-9]{0,8})(?:/|$)');

/// Where to send a browser once it is signed in: [next] when it is a path on
/// this origin outside `/auth/`, and `/` otherwise, so the sign-in page
/// cannot be used to send anyone elsewhere.
String safeNext(String? next) {
  if (next == null || !next.startsWith('/') || next.startsWith('/auth/')) return '/';
  if (next.contains(r'\') || next.codeUnits.any((c) => c < 0x20 || c == 0x7f)) return '/';
  // `//host` and `///host` parse with an authority, so this also refuses
  // a protocol-relative address.
  final uri = Uri.tryParse(next);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return '/';
  return next;
}

Future<void> _chmod(String path, String mode) async {
  if (Platform.isWindows) return;
  final r = await Process.run('chmod', [mode, path]);
  if (r.exitCode != 0) throw ProcessException('chmod', [mode, path], r.stderr.toString(), r.exitCode);
}
