/// Unit tests for the shared PTY-dimension clamp (`pty_size.dart`). Both
/// backends route spawn + resize through it so a degenerate (0/1) terminal
/// size can never reach a child — see microsoft/terminal#19922.
library;

import 'package:clide/src/pty/pty_size.dart';
import 'package:test/test.dart';

void main() {
  group('clampPtyDimension', () {
    test('raises sub-minimum values to the floor', () {
      expect(clampPtyDimension(0), minPtyDimension);
      expect(clampPtyDimension(1), minPtyDimension);
      expect(clampPtyDimension(-5), minPtyDimension);
    });

    test('passes through values at or above the floor', () {
      expect(clampPtyDimension(minPtyDimension), minPtyDimension);
      expect(clampPtyDimension(80), 80);
      expect(clampPtyDimension(24), 24);
    });
  });
}
