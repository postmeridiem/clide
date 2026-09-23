/// Manual "check for updates" logic for the About dialog and `clide app update`
/// (T-47 P1, story T-46; installing is `SelfUpdater`, T-621).
///
/// POLICY-sensitive: this is clide's ONLY outbound HTTP call, and it runs ONLY
/// on explicit user action (the About-box button) — never on a launch path, never
/// on a timer. It sends NO data about the user (a plain GET to the GitHub Releases
/// API), so it doesn't offend D-64's no-telemetry commitment. A background/periodic
/// poll would need a deliberate D-64 amendment first and is deferred.
library;

import 'dart:convert';
import 'dart:io';

/// Injectable GET → response body (throws on failure). Lets the check run
/// against a fake in tests so no widget test touches the network.
typedef GithubFetch = Future<String> Function(Uri url);

sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

/// Already on (or ahead of) the latest published release.
class UpdateUpToDate extends UpdateCheckResult {
  const UpdateUpToDate(this.current);
  final String current;
}

/// A newer release is available.
class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable({required this.latest, required this.url, this.bundle});
  final String latest;
  final String url;

  /// The release's installable bundle for this platform, with the SHA-256
  /// GitHub recorded for it (T-621). Null when the release carries none (a
  /// platform the release doesn't build, or a release without a digest).
  final ReleaseBundle? bundle;
}

/// One release asset clide can install: the platform tarball the release
/// workflow publishes (`clide-linux-x64-<version>.tar.gz`).
class ReleaseBundle {
  const ReleaseBundle({required this.name, required this.url, required this.sha256, required this.size});
  final String name;
  final String url;

  /// Lower-case hex SHA-256 from the asset's `digest` (`sha256:<hex>`),
  /// computed by GitHub at upload — the interim integrity check until
  /// releases are signed (T-491).
  final String sha256;
  final int size;
}

/// The release asset name for [version] on this machine, or null where
/// releases publish no bundle (only Linux x64 today — the Windows build is
/// paused, macOS has none yet).
String? bundleAssetName(String version, {bool? isLinux}) => (isLinux ?? Platform.isLinux) ? 'clide-linux-x64-$version.tar.gz' : null;

ReleaseBundle? _bundleFrom(Object? assets, String version, {bool? isLinux}) {
  final want = bundleAssetName(version, isLinux: isLinux);
  if (want == null || assets is! List) return null;
  for (final a in assets.whereType<Map<String, Object?>>()) {
    if (a['name'] != want) continue;
    final digest = a['digest'];
    final url = a['browser_download_url'];
    if (digest is! String || !digest.startsWith('sha256:') || url is! String) return null;
    return ReleaseBundle(name: want, url: url, sha256: digest.substring(7).toLowerCase(), size: (a['size'] as num?)?.toInt() ?? 0);
  }
  return null;
}

/// The check couldn't complete (offline, API error, parse failure). The app is
/// fully functional regardless — the failure is surfaced, never silent.
class UpdateCheckFailed extends UpdateCheckResult {
  const UpdateCheckFailed(this.message);
  final String message;
}

/// clide's only outbound HTTP — a plain GET, identifying as `clide`, no body.
Future<String> githubGet(Uri url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(url);
    req.headers.set(HttpHeaders.userAgentHeader, 'clide');
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final resp = await req.close();
    if (resp.statusCode != 200) throw HttpException('HTTP ${resp.statusCode}');
    return resp.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}

/// Pull `owner/repo` from a GitHub URL (`https://github.com/owner/repo[.git]`).
({String owner, String repo})? parseGithubRepo(String repositoryUrl) {
  final m = RegExp(r'github\.com[/:]([^/]+)/([^/.\s]+)').firstMatch(repositoryUrl);
  return m == null ? null : (owner: m.group(1)!, repo: m.group(2)!);
}

/// Fetch the latest GitHub Release for [repositoryUrl] and compare its version
/// to [currentVersion]. Never throws — failures come back as [UpdateCheckFailed].
Future<UpdateCheckResult> checkForUpdate({required String repositoryUrl, required String currentVersion, GithubFetch fetch = githubGet, bool? isLinux}) async {
  final gh = parseGithubRepo(repositoryUrl);
  if (gh == null) return const UpdateCheckFailed('unrecognized repository URL');
  try {
    final body = await fetch(Uri.parse('https://api.github.com/repos/${gh.owner}/${gh.repo}/releases/latest'));
    final json = jsonDecode(body) as Map<String, Object?>;
    final tag = (json['tag_name'] as String?)?.trim() ?? '';
    final latest = tag.startsWith('v') ? tag.substring(1) : tag;
    if (latest.isEmpty) return const UpdateCheckFailed('no release version found');
    final url = (json['html_url'] as String?) ?? repositoryUrl;
    if (compareSemver(latest, currentVersion) <= 0) return UpdateUpToDate(currentVersion);
    return UpdateAvailable(
      latest: latest,
      url: url,
      bundle: _bundleFrom(json['assets'], latest, isLinux: isLinux),
    );
  } catch (e) {
    return UpdateCheckFailed('$e');
  }
}

/// Minimal semver compare → -1/0/1 for a<b / a==b / a>b. Compares
/// major.minor.patch numerically (so 2.3.10 > 2.3.9), and ranks a pre-release
/// BELOW the same release (2.8.2-rc < 2.8.2). Missing components count as 0.
int compareSemver(String a, String b) {
  (List<int>, String) parse(String v) {
    final dash = v.indexOf('-');
    final core = dash >= 0 ? v.substring(0, dash) : v;
    final pre = dash >= 0 ? v.substring(dash + 1) : '';
    final nums = [for (final p in core.split('.')) int.tryParse(p.trim()) ?? 0];
    while (nums.length < 3) {
      nums.add(0);
    }
    return (nums, pre);
  }

  final (an, ap) = parse(a);
  final (bn, bp) = parse(b);
  for (var i = 0; i < 3; i++) {
    if (an[i] != bn[i]) return an[i] < bn[i] ? -1 : 1;
  }
  if (ap.isEmpty && bp.isEmpty) return 0;
  if (ap.isEmpty) return 1; // release outranks a pre-release of the same core
  if (bp.isEmpty) return -1;
  return ap.compareTo(bp);
}
