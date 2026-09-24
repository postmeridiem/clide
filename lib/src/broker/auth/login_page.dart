/// The sign-in page (D-118) the broker serves at `/auth/login`. It is static
/// apart from escaped values, and its one script and one style are allowed
/// by hash, so its Content-Security-Policy allows nothing else.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Moves a token or link from the URL's fragment into the form and submits
/// it. The fragment never reaches a server or a `Referer`, and the page takes
/// it off the address bar before posting.
const loginScript = r'''
(function () {
  var found = /^#(?:token|link)=([A-Za-z0-9_-]+)$/.exec(location.hash);
  if (!found) return;
  history.replaceState(null, '', location.pathname + location.search);
  var form = document.getElementById('signin');
  form.elements.token.value = found[1];
  form.submit();
})();
''';

const loginStyle = '''
body { font: 16px/1.5 system-ui, sans-serif; margin: 0; display: grid; place-items: center; min-height: 100vh; background: #1e1f29; color: #e6e6ef; }
main { width: min(24rem, calc(100vw - 2rem)); }
h1 { font-size: 1.4rem; font-weight: 500; }
label { display: block; margin: 1rem 0 0.25rem; }
input { box-sizing: border-box; width: 100%; padding: 0.5rem; font: inherit; color: inherit; background: #2a2b38; border: 1px solid #4a4b5c; border-radius: 4px; }
button { margin-top: 1rem; padding: 0.5rem 1rem; font: inherit; color: #1e1f29; background: #8fb8d9; border: 0; border-radius: 4px; cursor: pointer; }
.error { color: #f0a0a0; }
''';

/// The page's Content-Security-Policy: its own script and style by hash, a
/// form that posts to this origin, and nothing else.
final String loginPageCsp = [
  "default-src 'none'",
  "script-src 'sha256-${_hash(loginScript)}'",
  "style-src 'sha256-${_hash(loginStyle)}'",
  "form-action 'self'",
  "frame-ancestors 'none'",
  "base-uri 'none'",
].join('; ');

/// The page, with [next] as where the browser goes once signed in, and a
/// notice when the last attempt [failed].
String loginPage({required String next, required bool failed}) {
  const escape = HtmlEscape(HtmlEscapeMode.attribute);
  return '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sign in · clide</title>
<style>$loginStyle</style>
</head>
<body>
<main>
<h1>Sign in to clide</h1>
${failed ? '<p class="error" role="alert">That token or link was not accepted.</p>\n' : ''}<p>Open the sign-in link the installer printed, or paste its access token here.</p>
<form id="signin" method="post" action="/auth/login">
<label for="token">Access token</label>
<input id="token" name="token" type="password" autocomplete="off" required>
<input type="hidden" name="next" value="${escape.convert(next)}">
<button type="submit">Sign in</button>
</form>
</main>
<script>$loginScript</script>
</body>
</html>
''';
}

String _hash(String text) => base64.encode(sha256.convert(utf8.encode(text)).bytes);
