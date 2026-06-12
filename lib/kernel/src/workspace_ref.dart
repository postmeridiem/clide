/// WorkspaceRef (T-332): where a workspace lives — a local repo root or
/// a repo on a remote host reached over SSH (T-329).
///
/// The remote form is written `ssh://[user@]host[:port]/abs/remote/path`
/// (host may be a `~/.ssh/config` alias — resolution happens at connect
/// time, not here). A bare string with no scheme is a local path.
library;

/// A reference to a workspace root. Immutable value type.
class WorkspaceRef {
  const WorkspaceRef.local(this.path) : host = null, port = null, user = null;

  const WorkspaceRef.remote({required String this.host, required this.path, this.port, this.user});

  /// Remote host (or `~/.ssh/config` alias). Null means local.
  final String? host;

  /// SSH port; null means the ssh default / config-resolved port.
  final int? port;

  /// SSH user; null means the local username / config-resolved user.
  final String? user;

  /// Absolute workspace path — on [host] when remote, locally otherwise.
  final String path;

  bool get isRemote => host != null;

  /// Parse either a plain local path or an `ssh://` URI. Returns null
  /// for a malformed `ssh://` form (no host, or no absolute path).
  static WorkspaceRef? parse(String input) {
    if (!input.startsWith('ssh://')) return WorkspaceRef.local(input);
    final Uri uri;
    try {
      uri = Uri.parse(input);
    } on FormatException {
      return null;
    }
    if (uri.host.isEmpty || uri.path.isEmpty || uri.path == '/') return null;
    return WorkspaceRef.remote(host: uri.host, path: uri.path, port: uri.hasPort ? uri.port : null, user: uri.userInfo.isEmpty ? null : uri.userInfo);
  }

  /// The canonical string form: the bare path locally, the full
  /// `ssh://` URI remotely. `parse(uri) == ref` round-trips.
  String get uri {
    if (!isRemote) return path;
    final auth = user == null ? host! : '$user@$host';
    final p = port == null ? '' : ':$port';
    return 'ssh://$auth$p$path';
  }

  /// Compact human form for recents/switcher rows: `host:path` remotely
  /// (e.g. `buildbox:/srv/repo`), the bare path locally.
  String get display => isRemote ? '$host:$path' : path;

  @override
  bool operator ==(Object other) => other is WorkspaceRef && other.host == host && other.port == port && other.user == user && other.path == path;

  @override
  int get hashCode => Object.hash(host, port, user, path);

  @override
  String toString() => 'WorkspaceRef($uri)';
}
