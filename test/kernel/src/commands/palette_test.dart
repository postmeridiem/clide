import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

CommandContribution _cmd(String id, {String? title}) => CommandContribution(
      id: id,
      command: id,
      title: title,
      run: (_) async => IpcResponse.ok(id: '', data: const {}),
    );

void main() {
  group('PaletteController', () {
    late CommandRegistry registry;
    late PaletteController palette;

    setUp(() {
      registry = CommandRegistry();
      registry.register(_cmd('git.commit', title: 'Git: Commit'));
      registry.register(_cmd('git.push', title: 'Git: Push'));
      registry.register(_cmd('theme.pick', title: 'Theme: Pick…'));
      palette = PaletteController(registry);
    });

    test('open/close toggles isOpen and clears filter', () {
      palette.open();
      palette.setFilter('git');
      expect(palette.isOpen, true);
      expect(palette.filter, 'git');
      palette.close();
      expect(palette.isOpen, false);
      expect(palette.filter, '');
    });

    test('filtered empty filter returns all commands', () {
      expect(palette.filtered().length, 3);
    });

    test('filter is case-insensitive against title or command', () {
      palette.setFilter('git');
      expect(
        palette.filtered().map((c) => c.command).toSet(),
        {'git.commit', 'git.push'},
      );
      palette.setFilter('PICK');
      expect(
        palette.filtered().map((c) => c.command).toSet(),
        {'theme.pick'},
      );
    });

    test('invoke closes the palette + runs the command', () async {
      palette.open();
      palette.setFilter('git');
      await palette.invoke('git.commit');
      expect(palette.isOpen, false);
      expect(palette.filter, '');
    });
  });
}
