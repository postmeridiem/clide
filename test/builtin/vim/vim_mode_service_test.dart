/// T-207: the Vim mode service mirrors the active mode into the keymap as
/// mutually-exclusive `vim.*` scope flags, and clears them when disabled.
library;

import 'package:clide/builtin/vim/vim.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  late VimModeService mode;

  setUp(() async {
    f = await KernelFixture.create();
    mode = VimModeService(f.services.keymap);
  });
  tearDown(() {
    mode.dispose();
    return f.dispose();
  });

  bool flag(String name) => f.services.keymap.scope[name] ?? false;

  test('disabled by default and pushes no scope flags', () {
    expect(mode.enabled, isFalse);
    expect(flag('vim.normal'), isFalse);
    expect(flag('vim.insert'), isFalse);
    expect(flag('vim.visual'), isFalse);
  });

  test('enabling resets to normal and publishes exactly one flag', () {
    mode.enabled = true;
    expect(mode.mode, VimMode.normal);
    expect(flag('vim.normal'), isTrue);
    expect(flag('vim.insert'), isFalse);
    expect(flag('vim.visual'), isFalse);
  });

  test('mode transitions keep flags mutually exclusive', () {
    mode.enabled = true;

    mode.enterInsert();
    expect(mode.mode, VimMode.insert);
    expect(flag('vim.insert'), isTrue);
    expect(flag('vim.normal'), isFalse);

    mode.enterVisual();
    expect(flag('vim.visual'), isTrue);
    expect(flag('vim.insert'), isFalse);

    mode.enterNormal();
    expect(flag('vim.normal'), isTrue);
    expect(flag('vim.visual'), isFalse);
  });

  test('transitions are inert while disabled', () {
    mode.enterInsert();
    expect(mode.mode, VimMode.normal); // unchanged
    expect(flag('vim.insert'), isFalse);
  });

  test('disabling clears every vim flag', () {
    mode.enabled = true;
    mode.enterInsert();
    expect(flag('vim.insert'), isTrue);

    mode.enabled = false;
    expect(flag('vim.normal'), isFalse);
    expect(flag('vim.insert'), isFalse);
    expect(flag('vim.visual'), isFalse);
  });

  test('notifies listeners on enable and on mode change', () {
    var n = 0;
    mode.addListener(() => n++);
    mode.enabled = true; // 1
    mode.enterInsert(); // 2
    mode.enterInsert(); // no-op, same mode
    mode.enterNormal(); // 3
    expect(n, 3);
  });
}
