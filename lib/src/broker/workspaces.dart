/// The workspaces of each web user (D-119): every folder directly inside that
/// user's projects folder, `<root>/<N>/projects`. A workspace's slug is its
/// folder's name, unchanged, so the filesystem keeps slugs unique.
library;

import 'dart:io';

import 'environment.dart';

/// Where the container mounts each user's projects folder (D-119).
const defaultUsersRoot = '/clide/users';

/// Why [name] cannot be a workspace's slug, or null when it can (D-119). A
/// folder with such a name is skipped and reported, never renamed.
String? workspaceNameProblem(String name) {
  if (name.length > 64) return 'the name is longer than 64 characters';
  if (!_nameCharacters.hasMatch(name)) return 'the name has characters other than A-Z, a-z, 0-9, ".", "_" and "-"';
  if (name.startsWith('.') || name.startsWith('-')) return 'the name starts with "${name[0]}"';
  return null;
}

final _nameCharacters = RegExp(r'^[A-Za-z0-9._-]+$');

/// A folder the registry left out, and why.
typedef SkippedFolder = ({String name, String reason});

final class WorkspaceRegistry {
  const WorkspaceRegistry(this.root);

  /// The folder that holds `<N>/projects` for each user.
  final String root;

  /// [user]'s projects folder.
  String projects(int user) => '$root/$user/projects';

  /// The folder of [user]'s workspace [slug], or null when there is none: no
  /// folder of that name, a name the rule refuses, or a symbolic link. It
  /// looks each time, so a folder added while the broker runs is found on the
  /// next request for it.
  String? find(int user, String slug) {
    if (workspaceNameProblem(slug) != null) return null;
    final path = '${projects(user)}/$slug';
    return FileSystemEntity.typeSync(path, followLinks: false) == FileSystemEntityType.directory ? path : null;
  }

  /// [user]'s workspaces by slug, in order, and the folders left out. Files
  /// are not folders, so they are neither.
  ({List<String> slugs, List<SkippedFolder> skipped}) scan(int user) {
    final folder = Directory(projects(user));
    if (!folder.existsSync()) {
      throw BrokerConfigException('There is no projects folder at ${folder.path}. Mount one there (D-119).');
    }
    final slugs = <String>[];
    final skipped = <SkippedFolder>[];
    for (final entry in folder.listSync(followLinks: false)) {
      final name = entry.path.substring(folder.path.length + 1);
      if (entry is Link) {
        skipped.add((name: name, reason: 'it is a symbolic link, and links are not followed'));
      } else if (entry is Directory) {
        final problem = workspaceNameProblem(name);
        if (problem == null) {
          slugs.add(name);
        } else {
          skipped.add((name: name, reason: problem));
        }
      }
    }
    slugs.sort();
    skipped.sort((a, b) => a.name.compareTo(b.name));
    return (slugs: slugs, skipped: skipped);
  }
}
