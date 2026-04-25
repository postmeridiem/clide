/// Git diff data model and parser.
///
/// Shells out to `git diff` and parses unified-diff output into
/// typed [GitDiff] / [GitHunk] / [DiffLine] structures. Supports
/// both staged (`--cached`) and unstaged diffs.
library;

import 'dart:io';

import 'operations.dart' show gitBin;

enum DiffLineKind { context, addition, removal, header }

class DiffLine {
  const DiffLine({
    required this.kind,
    required this.text,
    this.oldLineNo,
    this.newLineNo,
  });

  final DiffLineKind kind;
  final String text;
  final int? oldLineNo;
  final int? newLineNo;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'text': text,
        if (oldLineNo != null) 'oldLineNo': oldLineNo,
        if (newLineNo != null) 'newLineNo': newLineNo,
      };
}

class GitHunk {
  const GitHunk({
    required this.header,
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    required this.lines,
  });

  final String header;
  final int oldStart;
  final int oldCount;
  final int newStart;
  final int newCount;
  final List<DiffLine> lines;

  int get additions => lines.where((l) => l.kind == DiffLineKind.addition).length;
  int get removals => lines.where((l) => l.kind == DiffLineKind.removal).length;

  String toPatch() {
    final buf = StringBuffer()..writeln(header);
    for (final line in lines) {
      switch (line.kind) {
        case DiffLineKind.addition:
          buf.writeln('+${line.text}');
        case DiffLineKind.removal:
          buf.writeln('-${line.text}');
        case DiffLineKind.context:
          buf.writeln(' ${line.text}');
        case DiffLineKind.header:
          buf.writeln(line.text);
      }
    }
    return buf.toString();
  }

  Map<String, Object?> toJson() => {
        'header': header,
        'oldStart': oldStart,
        'oldCount': oldCount,
        'newStart': newStart,
        'newCount': newCount,
        'additions': additions,
        'removals': removals,
        'lines': [for (final l in lines) l.toJson()],
      };
}

class GitDiff {
  const GitDiff({
    required this.path,
    required this.hunks,
    this.oldPath,
    this.isBinary = false,
    this.isNew = false,
    this.isDeleted = false,
    this.isRenamed = false,
  });

  final String path;
  final String? oldPath;
  final List<GitHunk> hunks;
  final bool isBinary;
  final bool isNew;
  final bool isDeleted;
  final bool isRenamed;

  int get additions => hunks.fold(0, (s, h) => s + h.additions);
  int get removals => hunks.fold(0, (s, h) => s + h.removals);

  Map<String, Object?> toJson() => {
        'path': path,
        if (oldPath != null) 'oldPath': oldPath,
        'binary': isBinary,
        'new': isNew,
        'deleted': isDeleted,
        'renamed': isRenamed,
        'additions': additions,
        'removals': removals,
        'hunks': [for (final h in hunks) h.toJson()],
      };
}

/// Run `git diff` and parse the result.
///
/// [staged] controls `--cached`. [paths] narrows to specific files.
Future<List<GitDiff>> gitDiff(
  Directory workDir, {
  bool staged = false,
  List<String> paths = const [],
}) async {
  final args = ['diff', '--unified=3'];
  if (staged) args.add('--cached');
  if (paths.isNotEmpty) {
    args.add('--');
    args.addAll(paths);
  }
  final result = await Process.run(
    gitBin,
    args,
    workingDirectory: workDir.path,
  );
  if (result.exitCode != 0) return const [];
  return parseDiffOutput(result.stdout as String);
}

/// Parse unified-diff text into [GitDiff] objects.
List<GitDiff> parseDiffOutput(String output) {
  if (output.isEmpty) return const [];
  final diffs = <GitDiff>[];
  final lines = output.split('\n');
  var i = 0;
  while (i < lines.length) {
    if (!lines[i].startsWith('diff --git ')) {
      i++;
      continue;
    }

    String? path;
    String? oldPath;
    var isBinary = false;
    var isNew = false;
    var isDeleted = false;
    var isRenamed = false;

    // Parse the diff header block.
    final diffLine = lines[i];
    final aMatch = RegExp(r'^diff --git a/(.+) b/(.+)$').firstMatch(diffLine);
    if (aMatch != null) {
      oldPath = aMatch.group(1);
      path = aMatch.group(2);
    }
    i++;

    while (i < lines.length && !lines[i].startsWith('diff --git ')) {
      final line = lines[i];
      if (line.startsWith('new file mode')) {
        isNew = true;
      } else if (line.startsWith('deleted file mode')) {
        isDeleted = true;
      } else if (line.startsWith('rename from ')) {
        isRenamed = true;
        oldPath = line.substring('rename from '.length);
      } else if (line.startsWith('rename to ')) {
        path = line.substring('rename to '.length);
      } else if (line.startsWith('Binary files')) {
        isBinary = true;
      } else if (line.startsWith('--- a/')) {
        oldPath = line.substring('--- a/'.length);
      } else if (line.startsWith('+++ b/')) {
        path = line.substring('+++ b/'.length);
      } else if (line.startsWith('@@')) {
        break; // Start parsing hunks.
      }
      i++;
    }

    if (path == null) {
      continue;
    }

    final hunks = <GitHunk>[];
    while (i < lines.length && !lines[i].startsWith('diff --git ')) {
      final line = lines[i];
      if (!line.startsWith('@@')) {
        i++;
        continue;
      }
      final hunk = _parseHunk(lines, i);
      if (hunk != null) {
        hunks.add(hunk.hunk);
        i = hunk.endIndex;
      } else {
        i++;
      }
    }

    diffs.add(GitDiff(
      path: path,
      oldPath: isRenamed ? oldPath : null,
      hunks: hunks,
      isBinary: isBinary,
      isNew: isNew,
      isDeleted: isDeleted,
      isRenamed: isRenamed,
    ));
  }
  return diffs;
}

class _HunkParseResult {
  const _HunkParseResult(this.hunk, this.endIndex);
  final GitHunk hunk;
  final int endIndex;
}

final _hunkHeaderRe = RegExp(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$');

_HunkParseResult? _parseHunk(List<String> lines, int start) {
  final match = _hunkHeaderRe.firstMatch(lines[start]);
  if (match == null) return null;

  final oldStart = int.parse(match.group(1)!);
  final oldCount = int.parse(match.group(2) ?? '1');
  final newStart = int.parse(match.group(3)!);
  final newCount = int.parse(match.group(4) ?? '1');
  final header = lines[start];

  final hunkLines = <DiffLine>[];
  var oldLine = oldStart;
  var newLine = newStart;
  var i = start + 1;

  while (i < lines.length) {
    final line = lines[i];
    if (line.startsWith('diff --git ') || line.startsWith('@@')) break;

    if (line.startsWith('+')) {
      hunkLines.add(DiffLine(
        kind: DiffLineKind.addition,
        text: line.substring(1),
        newLineNo: newLine,
      ));
      newLine++;
    } else if (line.startsWith('-')) {
      hunkLines.add(DiffLine(
        kind: DiffLineKind.removal,
        text: line.substring(1),
        oldLineNo: oldLine,
      ));
      oldLine++;
    } else if (line.startsWith(' ')) {
      hunkLines.add(DiffLine(
        kind: DiffLineKind.context,
        text: line.substring(1),
        oldLineNo: oldLine,
        newLineNo: newLine,
      ));
      oldLine++;
      newLine++;
    } else if (line == r'\ No newline at end of file') {
      hunkLines.add(DiffLine(
        kind: DiffLineKind.header,
        text: line,
      ));
    } else {
      break;
    }
    i++;
  }

  return _HunkParseResult(
    GitHunk(
      header: header,
      oldStart: oldStart,
      oldCount: oldCount,
      newStart: newStart,
      newCount: newCount,
      lines: hunkLines,
    ),
    i,
  );
}
