/// The broker's HTTP side (D-117, D-118): a server on a unix socket that only
/// Caddy reaches. It answers Caddy's forward-auth check for every request
/// outside `/auth/`, serves the sign-in and sign-out pages, and bridges each
/// session WebSocket to its workspace's host.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../auth/login_page.dart';
import '../auth/oidc.dart';
import '../auth/secrets.dart';
import '../auth/sessions.dart';
import '../environment.dart';
import '../serve_config.dart';
import '../store/broker_store.dart';
import '../supervise/hosts.dart';
import '../workspaces.dart';
import 'session_pipe.dart';

final class BrokerServer {
  BrokerServer._(
    this._server,
    this.path,
    this._store,
    this._config,
    this._sessions,
    this._oidc,
    this._workspaces,
    this._hosts,
    this._failureDelay,
    this._now,
    this._log,
  ) {
    _server.listen(_handle);
    _sweeper = Timer.periodic(const Duration(hours: 1), (_) => unawaited(_sweep()));
    unawaited(_sweep());
  }

  /// Serves on a unix socket at [path], which only this user can use (D-71):
  /// the socket is 0600 and a directory the broker creates is 0700. A socket
  /// left behind by a broker that is gone is replaced; one a running broker
  /// still answers on is not.
  ///
  /// In OIDC mode, [oidc] signs browsers in through the provider. Sessions
  /// open on [workspaces], bridged to [hosts]; without them every session is
  /// refused. [failureDelay] slows every refused sign-in down. [log] receives
  /// a line per sign-in, sign-out, session and failure; it never receives a
  /// secret.
  static Future<BrokerServer> bind(
    String path, {
    required BrokerStore store,
    required ServeConfig config,
    OidcClient? oidc,
    WorkspaceRegistry? workspaces,
    WorkspaceHosts? hosts,
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
    return BrokerServer._(server, path, store, config, sessions, oidc, workspaces, hosts, failureDelay, clock ?? DateTime.now, log ?? (_) {});
  }

  final HttpServer _server;
  final String path;
  final BrokerStore _store;
  final ServeConfig _config;
  final Sessions _sessions;
  final OidcClient? _oidc;
  final WorkspaceRegistry? _workspaces;
  final WorkspaceHosts? _hosts;
  final Duration _failureDelay;
  final DateTime Function() _now;
  final void Function(String line) _log;
  final _pipes = <SessionPipe>{};
  late final Timer _sweeper;

  /// Stops accepting requests and ends every open session. An upgraded
  /// session no longer belongs to the HTTP server, so it is ended here.
  Future<void> close() async {
    _sweeper.cancel();
    await _server.close(force: true);
    final open = [..._pipes];
    for (final pipe in open) {
      pipe.end(WebSocketStatus.goingAway, 'The broker is stopping.');
    }
    await Future.wait([for (final pipe in open) pipe.done]).timeout(const Duration(seconds: 5), onTimeout: () => []);
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
    // Not `no-referrer`: under it a browser sends `Origin: null` with the
    // sign-in form's POST, which the origin check must refuse. A token or
    // link travels in the URL's fragment, which no Referer ever carries.
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('x-content-type-options', 'nosniff')
      ..set('referrer-policy', 'same-origin');
    try {
      final session = _sessionPath.firstMatch(request.uri.path);
      if (session != null) {
        // An upgraded session belongs to its pipe, not to this response.
        if (await _openSession(request, int.parse(session[1]!), session[2]!)) return;
      } else {
        await _route(request);
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

  Future<void> _route(HttpRequest request) async {
    final response = request.response;
    switch ((request.method, request.uri.path)) {
      case ('GET', '/auth/verify'):
        await _verify(request);
      case ('GET', '/auth/login'):
        _signInPage(request);
      case ('POST', '/auth/login'):
        await _signIn(request);
      case ('POST', '/auth/logout'):
        await _signOut(request);
      case ('GET', '/auth/oidc') when _oidc != null:
        await _startOidc(request, _oidc);
      case ('GET', '/auth/callback') when _oidc != null:
        await _finishOidc(request, _oidc);
      case (_, '/auth/verify' || '/auth/login' || '/auth/logout'):
        _answer(response, 405, 'That method is not allowed here.');
      case (_, '/auth/oidc' || '/auth/callback') when _oidc != null:
        _answer(response, 405, 'That method is not allowed here.');
      default:
        _answer(response, 404, 'Not found.');
    }
  }

  /// `GET /u/<N>/w/<slug>/session`, the session WebSocket (D-117). It checks
  /// everything it can before upgrading, so a refusal is an ordinary HTTP
  /// answer rather than a socket that closes at once. Answers true once the
  /// request is upgraded and belongs to its pipe.
  Future<bool> _openSession(HttpRequest request, int user, String slug) async {
    final response = request.response;
    // dart:io reads nothing more on a connection that asked to upgrade, so a
    // refusal says the connection closes, and no client writes into it. Only
    // a refusal: on the 101 it would replace the `Connection: Upgrade` that a
    // proxy checks before it switches protocols.
    bool refuse(int status, String text) {
      response.persistentConnection = false;
      _answer(response, status, text);
      return false;
    }

    if (request.method != 'GET') return refuse(405, 'That method is not allowed here.');
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      response.headers.set(HttpHeaders.upgradeHeader, 'websocket');
      return refuse(426, 'This is a WebSocket endpoint.');
    }
    // A browser sends its page's origin with every WebSocket, so this is the
    // check that stops another site opening a session with the cookie.
    if (!_fromOwnOrigin(request)) return refuse(403, 'A session must come from ${_config.publicOrigin}.');
    final session = await _sessions.find(request.headers.value(HttpHeaders.cookieHeader));
    if (session == null) return refuse(401, 'Sign in first.');
    if (session.user != user) return refuse(403, 'This path belongs to another user.');
    final workspaces = _workspaces;
    final hosts = _hosts;
    if (workspaces == null || hosts == null) return refuse(503, 'This broker has no workspace host to start.');
    final workspace = workspaces.find(user, slug);
    if (workspace == null) return refuse(404, 'There is no such workspace.');
    final Socket host;
    try {
      host = await Socket.connect(InternetAddress(await hosts.attach(workspace), type: InternetAddressType.unix), 0);
    } on HostStartException catch (e) {
      _log(e.message);
      return refuse(503, 'The workspace host is not available.');
    } on SocketException catch (e) {
      _log('the host for $slug did not take the session: ${e.osError?.message ?? e.message}');
      return refuse(503, 'The workspace host is not available.');
    }
    final WebSocket browser;
    try {
      browser = await WebSocketTransformer.upgrade(request, compression: CompressionOptions.compressionOff);
    } catch (_) {
      host.destroy();
      rethrow;
    }
    // Pings find a browser that vanished without closing, and keep proxies
    // from dropping a quiet session.
    browser.pingInterval = const Duration(seconds: 30);
    final pipe = SessionPipe.open(browser, host);
    _pipes.add(pipe);
    _log('user $user opened a session on $slug');
    unawaited(
      pipe.done.whenComplete(() {
        _pipes.remove(pipe);
        _log('a session on $slug ended');
      }),
    );
    return true;
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
    request.response.write(loginPage(next: safeNext(query['next']), mode: _config.mode, error: query['error']));
  }

  /// `GET /auth/oidc`: starts a sign-in at the provider (D-118). Its `state`
  /// goes to the provider and, in a cookie, to this browser, so a callback
  /// counts only in the browser that began it.
  Future<void> _startOidc(HttpRequest request, OidcClient oidc) async {
    final response = request.response;
    final next = safeNext(request.uri.queryParameters['next']);
    final state = randomSecret();
    final nonce = randomSecret();
    final verifier = randomSecret();
    final Uri provider;
    try {
      provider = await oidc.authorizationUri(state: state, nonce: nonce, verifier: verifier);
    } on OidcException catch (e) {
      _log('an OIDC sign-in could not start: ${e.message}');
      _redirect(response, '/auth/login?error=provider&next=${Uri.encodeQueryComponent(next)}');
      return;
    }
    await _store.putOidcPending(
      OidcPending(stateHash: secretHash(state), nonce: nonce, verifier: verifier, nextPath: next, expiresAt: _now().add(oidcSigninLifetime)),
    );
    response.headers.add(HttpHeaders.setCookieHeader, '$_signinCookie=$state; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=${oidcSigninLifetime.inSeconds}');
    _redirect(response, '$provider', status: HttpStatus.found);
  }

  /// `GET /auth/callback`: the provider's answer. The flow must be this
  /// browser's, live, and taken once; the code is exchanged for an ID token,
  /// whose claims and allowlist decide the rest.
  Future<void> _finishOidc(HttpRequest request, OidcClient oidc) async {
    final response = request.response;
    final query = request.uri.queryParameters;
    response.headers.add(HttpHeaders.setCookieHeader, '$_signinCookie=; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0');
    final state = query['state'] ?? '';
    final bound = cookieSecret(request.headers.value(HttpHeaders.cookieHeader), _signinCookie);
    final pending = looksLikeSecret(state) && bound != null && sameHash(secretHash(bound), secretHash(state))
        ? await _store.takeOidcPending(secretHash(state))
        : null;
    if (pending == null) {
      _log('an OIDC sign-in came back that this browser did not start, or too late');
      _redirect(response, '/auth/login?error=expired');
      return;
    }
    final retry = '/auth/login?error=provider&next=${Uri.encodeQueryComponent(pending.nextPath)}';
    final error = query['error'];
    final code = query['code'];
    final issuer = query['iss'];
    // RFC 9207: a provider that names itself here must be this one.
    if (issuer != null && issuer != oidc.settings.issuer) {
      _log('an OIDC sign-in came back from another issuer, ${_quoted(issuer)}');
      _redirect(response, retry);
      return;
    }
    if (error != null || code == null || code.isEmpty) {
      _log('the provider did not sign the browser in: ${error == null ? 'no code' : _quoted(error)}');
      _redirect(response, retry);
      return;
    }
    final OidcIdentity identity;
    try {
      identity = await oidc.exchange(code: code, verifier: pending.verifier, nonce: pending.nonce);
    } on OidcException catch (e) {
      _log('an OIDC sign-in failed: ${e.message}');
      _redirect(response, retry);
      return;
    }
    if (!oidc.allows(identity)) {
      _log('an OIDC sign-in by subject ${_quoted(identity.subject)} is not on the allowlist');
      _redirect(response, '/auth/login?error=denied&next=${Uri.encodeQueryComponent(pending.nextPath)}');
      return;
    }
    response.headers.add(HttpHeaders.setCookieHeader, await _sessions.start(0, via: 'oidc', subject: identity.subject));
    _log('user 0 signed in by OIDC');
    _redirect(response, pending.nextPath);
  }

  /// Text from outside, quoted for the log with its control characters
  /// escaped, and cut short.
  static String _quoted(String text) => jsonEncode(text.length > 100 ? '${text.substring(0, 100)}…' : text);

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

/// How long a browser has to sign in at the provider and come back.
const oidcSigninLifetime = Duration(minutes: 10);

/// The cookie that binds an OIDC sign-in's `state` to the browser that began
/// it. `__Host-` keeps it to this origin, like the session's.
const _signinCookie = '__Host-clide_signin';

/// A session WebSocket's path, `/u/<N>/w/<slug>/session`. The registry judges
/// the slug.
final _sessionPath = RegExp(r'^/u/(0|[1-9][0-9]{0,8})/w/([^/]+)/session$');

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
