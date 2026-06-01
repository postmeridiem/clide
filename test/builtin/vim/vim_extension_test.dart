/// T-207: the Vim extension enables its layer only under the `vim` preset,
/// registers mode-transition commands (no global bindings), and drives the
/// mode through those commands.
library;

import 'package:clide/builtin/vim/vim.dart';
import 'package:clide/extension/extension.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  late VimExtension ext;

  setUp(() async {
    f = await KernelFixture.create();
    ext = VimExtension();
    f.services.extensions.register(ext);
  });
  tearDown(() => f.dispose());

  bool flag(String name) => f.services.keymap.scope[name] ?? false;

  test('inert under the default preset', () async {
    await f.services.extensions.activate('builtin.vim');
    expect(ext.modeService!.enabled, isFalse);
    expect(flag('vim.normal'), isFalse);
  });

  test('enables when the vim preset is active', () async {
    await f.services.keymap.setPreset('vim');
    await f.services.extensions.activate('builtin.vim');
    expect(ext.modeService!.enabled, isTrue);
    expect(flag('vim.normal'), isTrue);
  });

  test('follows a live preset switch', () async {
    await f.services.extensions.activate('builtin.vim');
    expect(ext.modeService!.enabled, isFalse);

    await f.services.keymap.setPreset('vim');
    expect(ext.modeService!.enabled, isTrue);

    await f.services.keymap.setPreset('default');
    expect(ext.modeService!.enabled, isFalse);
    expect(flag('vim.normal'), isFalse);
  });

  test('mode commands drive the scope flags', () async {
    await f.services.keymap.setPreset('vim');
    await f.services.extensions.activate('builtin.vim');

    await f.services.commands.execute('vim.mode.insert');
    expect(flag('vim.insert'), isTrue);
    expect(flag('vim.normal'), isFalse);

    await f.services.commands.execute('vim.mode.normal');
    expect(flag('vim.normal'), isTrue);
    expect(flag('vim.insert'), isFalse);
  });

  test('mode commands carry no default binding', () {
    final cmds = ext.contributions.whereType<CommandContribution>();
    expect(cmds, isNotEmpty);
    expect(cmds.every((c) => c.defaultBinding == null), isTrue);
  });

  test('deactivate clears flags and disables the layer', () async {
    await f.services.keymap.setPreset('vim');
    await f.services.extensions.activate('builtin.vim');
    await f.services.commands.execute('vim.mode.insert');
    expect(flag('vim.insert'), isTrue);

    final svc = ext.modeService!;
    await f.services.extensions.deactivate('builtin.vim');
    expect(svc.enabled, isFalse);
    expect(flag('vim.insert'), isFalse);
  });
}
