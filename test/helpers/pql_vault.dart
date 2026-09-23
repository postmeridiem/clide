/// A throwaway pql vault for tests (T-639).
///
/// The pql tests used to run against this repo's own `.pql/` planning DB —
/// reading live tickets and, via `decisions sync`, writing to it — and
/// asserted on whatever the plan happened to hold (T-6 being an epic over
/// T-1). They contended for its SQLite lock too, which is why they needed
/// the `serial` tag. This builds a small known vault in a temp dir instead:
///
///   notes/alpha.md   frontmatter (title, status: draft, tags: [fixture]),
///                    an `#inline-tag`, and a `[[beta]]` link
///   notes/beta.md    frontmatter (status: done) and a `[[alpha]]` link
///   governance/decisions/architecture.md
///                    D-1, and D-2 which references D-1
///   tickets          T-1 (epic) and its child T-2 (task, linked to D-1)
///
/// Flutter-free: used by suites that run under plain `dart test`.
library;

import 'dart:io';

import 'package:clide/kernel/src/toolchain_paths.dart';
import 'package:clide/src/pql/client.dart';

import 'git_sandbox.dart';

class PqlFixtureVault {
  PqlFixtureVault._(this.dir, this.pql);

  /// The vault root — hand it to a `PqlClient` as `workDir`.
  final Directory dir;

  /// The pql binary the vault was built with.
  final String pql;

  /// Whether a pql binary is available to build a vault with.
  static bool get available => resolveToolchainPaths().pql != null;

  /// Build the vault. Throws [StateError] if any setup step fails.
  static Future<PqlFixtureVault> create() async {
    final pql = resolveToolchainPaths().pql;
    if (pql == null) throw StateError('pql is not installed');
    final dir = await newSandboxRepo(prefix: 'clide-pql-vault-');
    final v = PqlFixtureVault._(dir, pql);
    await v._run(['init', '--with-skill=no']);
    v._write('notes/alpha.md', '---\ntitle: Alpha\nstatus: draft\ntags: [fixture]\n---\n\n# Alpha\n\nLinks to [[beta]]. #inline-tag\n');
    v._write('notes/beta.md', '---\ntitle: Beta\nstatus: done\n---\n\n# Beta\n\nBack to [[alpha]].\n');
    v._write(
      'governance/decisions/architecture.md',
      '# Architecture Decisions\n\n---\n\n'
          '### D-1: First fixture decision\n- **Date:** 2026-01-01\n- **Decision:** The fixture has a decision.\n- **Rationale:** Tests need one to read.\n\n'
          '### D-2: Second fixture decision\n- **Date:** 2026-01-02\n- **Decision:** It builds on [D-1](#d-1-first-fixture-decision).\n- **Rationale:** Tests need a cross-reference.\n',
    );
    // Decisions first: a ticket's --decision link needs D-1 in the DB.
    await v._run(['decisions', 'sync']);
    await v._run(['ticket', 'new', 'epic', 'Fixture epic', '--id-only']);
    await v._run(['ticket', 'new', 'task', 'Fixture child', '--parent', 'T-1', '--decision', 'D-1', '--id-only']);
    return v;
  }

  void _write(String rel, String content) {
    final f = File('${dir.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  Future<void> _run(List<String> args) async {
    // The client's scrubbed environment. An inherited PQL_VAULT would build
    // this fixture inside that vault instead of [dir] (T-693).
    final r = await Process.run(
      pql,
      args,
      workingDirectory: dir.path,
      environment: PqlClient.childEnvironment(Platform.environment),
      includeParentEnvironment: false,
    );
    if (r.exitCode != 0) {
      throw StateError('pql ${args.join(' ')} failed (${r.exitCode}): ${r.stderr}');
    }
  }

  void dispose() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
