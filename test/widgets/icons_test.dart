/// Smoke tests for the custom paint icons under `lib/widgets/src/icons/`.
/// Each paint() call runs against a real PictureRecorder canvas to verify
/// it doesn't throw and to fill in lcov.
library;

import 'dart:ui';

import 'package:clide/widgets/src/icons/check.dart';
import 'package:clide/widgets/src/icons/chevron.dart';
import 'package:clide/widgets/src/icons/dot.dart';
import 'package:clide/widgets/src/icons/folder.dart';
import 'package:clide/widgets/src/icons/gear.dart';
import 'package:clide/widgets/src/icons/git_branch.dart';
import 'package:clide/widgets/src/icons/plug.dart';
import 'package:clide/widgets/src/icons/search.dart';
import 'package:clide/widgets/src/icons/terminal_icon.dart';
import 'package:clide/widgets/src/icons/warning.dart';
import 'package:test/test.dart';

Canvas _canvas() => Canvas(PictureRecorder());

void main() {
  const color = Color(0xFF000000);

  test('every custom icon painter renders without throwing', () {
    const painters = [
      CheckIcon(),
      ChevronRightIcon(),
      ChevronDownIcon(),
      DotIcon(),
      FolderIcon(),
      GearIcon(),
      GitBranchIcon(),
      PlugIcon(),
      SearchIcon(),
      TerminalIcon(),
      WarningIcon(),
    ];
    for (final p in painters) {
      p.paint(_canvas(), color);
    }
  });
}
