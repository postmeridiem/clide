/// Regression guard for the `clide version` contract (T-213).
///
/// `clideVersion` (lib/src/build_info.g.dart, baked by gen-build-info)
/// is what the dispatcher returns for `ping`/`version` and what the C
/// client surfaces. An agent keys off `clide version`; if it ever drifts
/// from pubspec.yaml `version:` — the single source of truth — that agent
/// is misled. This test fails the moment the two diverge.
library;

import 'dart:io';

import 'package:clide/clide.dart' show clideVersion;
import 'package:test/test.dart';

/// First `version:` entry in pubspec.yaml — mirrors the Makefile awk
/// (`/^version:/ {gsub(/[" ]/,"",$2); print $2}`).
String _pubspecVersion() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  for (final line in lines) {
    if (line.startsWith('version:')) {
      return line.substring('version:'.length).replaceAll('"', '').trim();
    }
  }
  fail('no `version:` line in pubspec.yaml');
}

void main() {
  test('clideVersion matches pubspec.yaml version (T-213)', () {
    expect(clideVersion, _pubspecVersion(), reason: 'build_info.g.dart drifted from pubspec.yaml — run `make gen-build-info`');
  });
}
