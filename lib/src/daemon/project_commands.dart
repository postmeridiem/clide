/// `clide project new <name> [--dir <parent>]` — create a new clide project
/// (T-487, story T-486). clide treats a git repo as the workspace, so a new
/// project is: a fresh directory, `git init`, and a minimal scaffold. The git
/// binary lives behind the toolchain in main.dart, so it's injected here as
/// [ProjectGitInit], keeping this handler Flutter-free (runs under `dart test`).
///
/// This verb creates only — opening the new workspace and the account roadblock
/// (T-488) are the UI flow's job; the CLI returns the created path.
library;

import 'dart:io';

import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';

/// MessageBus channel announcing a freshly-created project (path in `dir`). The
/// welcome new-project dialog publishes it after create + open; the Claude
/// extension consumes it to show the per-repo account roadblock (T-488) — only
/// NEW projects prompt, existing opens never do. Lives here in the neutral
/// daemon layer so both builtins name one literal without coupling to each other.
const projectCreatedChannel = 'project.created';

/// Runs `git init` in [dir]. Injected so this stays Flutter-free + testable;
/// main.dart wires it to the real toolchain.
typedef ProjectGitInit = Future<void> Function(String dir);

/// Outcome of a [createNewProject] attempt — the created path, or a clear error.
class NewProjectResult {
  const NewProjectResult.ok(String this.path) : error = null;
  const NewProjectResult.err(String this.error) : path = null;
  final String? path;
  final String? error;
  bool get ok => error == null;
}

/// Validate a project name: a single folder segment, not a path or a dot-name.
String? validateProjectName(String name) {
  final n = name.trim();
  if (n.isEmpty) return 'project name is required';
  if (n.contains('/') || n.contains(r'\')) return 'name must be a single folder, not a path';
  if (n == '.' || n == '..' || n.startsWith('.')) return 'invalid project name: "$name"';
  return null;
}

/// Create `<parent>/<name>/`, `git init` it (via [gitInit]), and write a minimal
/// scaffold. Never overwrites an existing entry. Returns the created path or a
/// clear, user-facing error.
Future<NewProjectResult> createNewProject({required String parent, required String name, required ProjectGitInit gitInit}) async {
  final nameErr = validateProjectName(name);
  if (nameErr != null) return NewProjectResult.err(nameErr);

  final trimmedParent = _stripTrailingSep(parent.trim());
  if (trimmedParent.isEmpty) return NewProjectResult.err('a parent directory is required');
  if (!Directory(trimmedParent).existsSync()) return NewProjectResult.err('parent directory does not exist: $trimmedParent');

  final target = '$trimmedParent/${name.trim()}';
  if (Directory(target).existsSync() || File(target).existsSync()) {
    return NewProjectResult.err('already exists: $target');
  }

  Directory(target).createSync(recursive: true);
  await gitInit(target);
  _writeScaffold(target, name.trim());
  return NewProjectResult.ok(target);
}

/// `git init` an EXISTING folder that isn't a repo yet (T-489) — the "initialize
/// this folder as a clide project" path. Unlike [createNewProject] it never
/// creates the dir and never clobbers existing files; the scaffold is only
/// written where absent.
Future<NewProjectResult> initExistingProject({required String path, required ProjectGitInit gitInit}) async {
  final trimmed = _stripTrailingSep(path.trim());
  if (trimmed.isEmpty) return NewProjectResult.err('a directory is required');
  if (!Directory(trimmed).existsSync()) return NewProjectResult.err('directory does not exist: $trimmed');
  await gitInit(trimmed);
  _writeScaffold(trimmed, trimmed.split('/').where((s) => s.isNotEmpty).lastOrNull ?? 'project');
  return NewProjectResult.ok(trimmed);
}

void _writeScaffold(String dir, String name) {
  // Minimal + non-prescriptive: keep clide's own state out of git, and orient
  // Claude with an empty CLAUDE.md stub. No language/framework templates. Never
  // clobbers — safe to run over an existing folder (T-489).
  final gitignore = File('$dir/.gitignore');
  if (!gitignore.existsSync()) gitignore.writeAsStringSync('# clide\n.clide/\n');
  final claudeMd = File('$dir/CLAUDE.md');
  if (!claudeMd.existsSync()) claudeMd.writeAsStringSync('# $name\n\nGuidance for Claude Code in this project.\n');
}

String _stripTrailingSep(String p) {
  var s = p;
  while (s.length > 1 && (s.endsWith('/') || s.endsWith(r'\'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Register `project.new` + `project.init`. [gitInit] runs git init;
/// [defaultParent] supplies the new-project parent when `--dir` is omitted (the
/// current workspace's parent); [defaultInitPath] supplies the init target when
/// `--dir` is omitted (the current workspace, so `clide project init` inits the
/// folder you're in).
void registerProjectCommands(DaemonDispatcher d, {required ProjectGitInit gitInit, String? Function()? defaultParent, String? Function()? defaultInitPath}) {
  d.register('project.new', (req) async {
    final name = (req.args['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return _err(req.id, 'project new requires a <name>');
    final parent = (req.args['dir'] as String?)?.trim() ?? defaultParent?.call();
    if (parent == null || parent.isEmpty) {
      return _err(req.id, 'no parent directory to create in', hint: 'pass --dir <parent>');
    }
    final result = await createNewProject(parent: parent, name: name, gitInit: gitInit);
    if (!result.ok) return _err(req.id, result.error!);
    return IpcResponse.ok(id: req.id, data: {'path': result.path, 'name': name});
  }, schema: const CommandSchema(positional: ['name'], args: {'name': ArgSpec(required: true, rejectLeadingDash: true), 'dir': ArgSpec()}));

  d.register('project.init', (req) async {
    final path = (req.args['dir'] as String?)?.trim() ?? defaultInitPath?.call();
    if (path == null || path.isEmpty) return _err(req.id, 'no directory to initialize', hint: 'pass --dir <path>');
    final result = await initExistingProject(path: path, gitInit: gitInit);
    if (!result.ok) return _err(req.id, result.error!);
    return IpcResponse.ok(id: req.id, data: {'path': result.path});
  }, schema: const CommandSchema(args: {'dir': ArgSpec()}));
}

IpcResponse _err(String id, String message, {String? hint}) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message, hint: hint),
);
