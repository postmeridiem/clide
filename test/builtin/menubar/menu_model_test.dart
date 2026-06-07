/// Resolver + controller tests for the application menu (T-48). Pure-ish: uses
/// the kernel fixture for a real CommandRegistry but no widgets.
library;

import 'package:clide/builtin/menubar/menubar.dart';
import 'package:clide/builtin/menubar/src/menu_model.dart';
import 'package:clide/clide.dart' show IpcResponse;
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  void cmd(String id, {String? title, String? binding}) {
    f.services.commands.register(CommandContribution(
      id: id,
      command: id,
      title: title,
      defaultBinding: binding,
      run: (_) async => IpcResponse.ok(id: '', data: const {}),
    ));
  }

  group('resolveMenus', () {
    test('curated order: strips "Category:" titles, separators pass through, defaultBinding shows', () {
      cmd('a.one', title: 'A: One', binding: 'ctrl+1');
      final tree = [
        TopMenu(title: 'A', mnemonic: 0, nodes: const [
          MenuCommandItem('a.one'),
          MenuSeparator(),
          MenuCommandItem('a.missing', fallbackTitle: 'Missing'),
        ]),
      ];
      final items = resolveMenus(tree, f.services.commands, f.services).single.items;

      expect(items, hasLength(3));
      final one = items[0] as ResolvedItem;
      expect(one.title, 'One'); // "A: One" → "One"
      expect(one.enabled, isTrue);
      expect(one.keybinding, 'Ctrl+1');
      expect(items[1], isA<ResolvedSeparator>());
      final missing = items[2] as ResolvedItem;
      expect(missing.title, 'Missing'); // fallback used (unregistered)
      expect(missing.enabled, isFalse); // unregistered → disabled
      expect(missing.keybinding, isNull);
    });

    test('auto-fill appends unplaced prefixed commands sorted, excluding placed', () {
      cmd('view.zoomIn', title: 'View: Zoom In');
      cmd('view.beta', title: 'View: Beta');
      cmd('view.alpha', title: 'View: Alpha');
      final tree = [
        TopMenu(title: 'View', mnemonic: 0, nodes: const [
          MenuCommandItem('view.zoomIn'),
          MenuSeparator(),
          MenuAutoFill('view.'),
        ]),
      ];
      final items = resolveMenus(tree, f.services.commands, f.services).single.items.whereType<ResolvedItem>().toList();
      // zoomIn (placed) first; then auto-filled Alpha, Beta sorted by title;
      // zoomIn NOT duplicated by the auto-fill.
      expect(items.map((i) => i.title).toList(), ['Zoom In', 'Alpha', 'Beta']);
    });

    test('enabledWhen gates enablement independently of registration', () {
      cmd('x.cmd', title: 'X: Cmd');
      List<ResolvedItem> resolve(bool Function(KernelServices) when) {
        final tree = [
          TopMenu(title: 'X', mnemonic: 0, nodes: [MenuCommandItem('x.cmd', enabledWhen: when)]),
        ];
        return resolveMenus(tree, f.services.commands, f.services).single.items.cast<ResolvedItem>();
      }

      expect(resolve((_) => false).single.enabled, isFalse);
      expect(resolve((_) => true).single.enabled, isTrue);
    });

    test('keymap binding label overrides the contribution defaultBinding', () {
      cmd('k.cmd', title: 'K: Cmd', binding: 'ctrl+1');
      final tree = [
        TopMenu(title: 'K', mnemonic: 0, nodes: const [MenuCommandItem('k.cmd')]),
      ];
      final item = resolveMenus(
        tree,
        f.services.commands,
        f.services,
        bindingLabel: (id) => id == 'k.cmd' ? 'Ctrl+K' : null,
      ).single.items.first as ResolvedItem;
      expect(item.keybinding, 'Ctrl+K');
    });
  });

  group('buildClideMenuTree', () {
    test('is File / View / Help with first-letter mnemonics', () {
      final tree = buildClideMenuTree();
      expect(tree.map((m) => m.title).toList(), ['File', 'View', 'Help']);
      expect(tree.map((m) => m.mnemonicChar).toList(), ['f', 'v', 'h']);
    });
  });

  group('MenuBarController', () {
    test('open / close / toggle track a single open index', () {
      final c = MenuBarController();
      expect(c.isOpen, isFalse);
      c.open(1);
      expect(c.openIndex, 1);
      c.toggle(1); // same index → close
      expect(c.isOpen, isFalse);
      c.toggle(2); // different → open
      expect(c.openIndex, 2);
    });

    test('mnemonic lookup + openNext/openPrev wrap', () {
      final c = MenuBarController()..setMnemonics(['f', 'v', 'h']);
      expect(c.indexForMnemonic('V'), 1);
      expect(c.indexForMnemonic('z'), isNull);
      c.open(2);
      c.openNext(); // wraps 2 → 0
      expect(c.openIndex, 0);
      c.openPrev(); // wraps 0 → 2
      expect(c.openIndex, 2);
    });
  });
}
