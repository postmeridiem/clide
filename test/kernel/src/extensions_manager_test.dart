import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

/// Minimal no-op extension used as a test actor.
class _Ext extends ClideExtension {
  _Ext({required this.id, this.dependsOn = const [], this.contributions = const [], this.onActivate, this.onDeactivate});

  @override
  final String id;
  @override
  String get title => id;
  @override
  String get version => '0.0.0-test';
  @override
  final List<String> dependsOn;
  @override
  final List<ContributionPoint> contributions;

  final Future<void> Function(ClideExtensionContext ctx)? onActivate;
  final Future<void> Function()? onDeactivate;

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    if (onActivate != null) await onActivate!(ctx);
  }

  @override
  Future<void> deactivate() async {
    if (onDeactivate != null) await onDeactivate!();
  }
}

void main() {
  group('ExtensionManager', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create();
    });

    tearDown(() async {
      await f.dispose();
    });

    test('register + activateAll runs extensions in dep order', () async {
      final order = <String>[];
      f.services.extensions
        ..register(_Ext(id: 'a', onActivate: (_) async => order.add('a')))
        ..register(_Ext(id: 'b', dependsOn: const ['a'], onActivate: (_) async => order.add('b')))
        ..register(_Ext(id: 'c', dependsOn: const ['b'], onActivate: (_) async => order.add('c')));
      await f.services.extensions.activateAll();
      expect(order, ['a', 'b', 'c']);
    });

    test('missing dep skips the dependent with a warning', () async {
      final order = <String>[];
      f.services.extensions.register(_Ext(id: 'needs-missing', dependsOn: const ['does.not.exist'], onActivate: (_) async => order.add('needs-missing')));
      await f.services.extensions.activateAll();
      expect(order, isEmpty);
      expect(f.services.extensions.isActivated('needs-missing'), false);
    });

    test('contribution points wire into panel registry on activate', () async {
      f.services.extensions.register(
        _Ext(
          id: 'with-tab',
          contributions: [TabContribution(id: 'with-tab.view', slot: Slots.workspace, title: 'T', build: (_) => const SizedBox.shrink())],
        ),
      );
      await f.services.extensions.activateAll();
      expect(f.services.panels.tabsFor(Slots.workspace).map((t) => t.id), ['with-tab.view']);
    });

    test('activating an extension auto-loads its localized tab namespace (T-155)', () async {
      final local = await KernelFixture.create(
        i18nCatalogs: {
          'ext.localized': {
            const Locale('en', 'US'): {
              'tab.title': {'translation': 'Localized'},
            },
          },
        },
        preloadNamespaces: const [], // loadable, but not preloaded at boot
      );
      addTearDown(local.dispose);

      // Not registered yet → string() falls back to the placeholder.
      expect(local.services.i18n.string('tab.title', namespace: 'ext.localized', placeholder: 'fallback'), 'fallback');

      local.services.extensions.register(
        _Ext(
          id: 'ext.localized',
          contributions: [
            TabContribution(
              id: 'ext.localized.view',
              slot: Slots.workspace,
              title: 'Fallback',
              titleKey: 'tab.title',
              i18nNamespace: 'ext.localized',
              build: (_) => const SizedBox.shrink(),
            ),
          ],
        ),
      );
      await local.services.extensions.activateAll();

      // Activation auto-loaded the catalog → resolves, no "namespace not
      // registered" warning.
      expect(local.services.i18n.string('tab.title', namespace: 'ext.localized', placeholder: 'fallback'), 'Localized');
    });

    test('deactivate removes contributions from the registry', () async {
      f.services.extensions.register(
        _Ext(
          id: 'ephemeral',
          contributions: [TabContribution(id: 'ephemeral.view', slot: Slots.workspace, title: 'T', build: (_) => const SizedBox.shrink())],
        ),
      );
      await f.services.extensions.activateAll();
      expect(f.services.panels.tabsFor(Slots.workspace), hasLength(1));
      await f.services.extensions.deactivate('ephemeral');
      expect(f.services.panels.tabsFor(Slots.workspace), isEmpty);
    });

    test('CommandContribution registers + default binding is bound', () async {
      f.services.extensions.register(
        _Ext(
          id: 'has-cmd',
          contributions: [
            CommandContribution(
              id: 'c',
              command: 'test.cmd',
              defaultBinding: 'ctrl+alt+k',
              run: (_) async => IpcResponse.ok(id: '', data: const {}),
            ),
          ],
        ),
      );
      await f.services.extensions.activateAll();
      expect(f.services.commands.get('test.cmd'), isNotNull);
      expect(f.services.keybindings.commandFor(Keybinding.parse('ctrl+alt+k')), 'test.cmd');
    });

    test('setEnabled=false deactivates; =true reactivates', () async {
      final order = <String>[];
      f.services.extensions.register(_Ext(id: 'toggle', onActivate: (_) async => order.add('on'), onDeactivate: () async => order.add('off')));
      await f.services.extensions.activateAll();
      expect(order, ['on']);
      await f.services.extensions.setEnabled('toggle', false);
      expect(order, ['on', 'off']);
      await f.services.extensions.setEnabled('toggle', true);
      expect(order, ['on', 'off', 'on']);
    });

    test('dependency cycle warns, does not infinite-loop', () async {
      f.services.extensions
        ..register(_Ext(id: 'x', dependsOn: const ['y']))
        ..register(_Ext(id: 'y', dependsOn: const ['x']));
      // Should not throw; both should fail to activate because of
      // unsatisfied deps.
      await f.services.extensions.activateAll();
      expect(f.services.extensions.isActivated('x'), false);
      expect(f.services.extensions.isActivated('y'), false);
    });

    test('emits ExtensionActivated / ExtensionDeactivated events', () async {
      final activated = <String>[];
      final deactivated = <String>[];
      final s1 = f.services.events.on<ExtensionActivated>().listen((e) => activated.add(e.id));
      final s2 = f.services.events.on<ExtensionDeactivated>().listen((e) => deactivated.add(e.id));
      f.services.extensions.register(_Ext(id: 'e'));
      await f.services.extensions.activateAll();
      await Future<void>.delayed(Duration.zero);
      await f.services.extensions.deactivate('e');
      await Future<void>.delayed(Duration.zero);
      expect(activated, ['e']);
      expect(deactivated, ['e']);
      await s1.cancel();
      await s2.cancel();
    });

    test('TrayItemContribution lands in TrayRegistry; deactivate removes it', () async {
      f.services.extensions.register(
        _Ext(
          id: 'tray-ext',
          contributions: [const TrayItemContribution(id: 'tray-ext.item', label: 'Item', onSelected: _noop)],
        ),
      );
      await f.services.extensions.activateAll();
      expect(f.services.tray.items.map((i) => i.id), contains('tray-ext.item'));
      await f.services.extensions.deactivate('tray-ext');
      expect(f.services.tray.items, isEmpty);
    });

    test('StatusItem + ToolbarButton contributions activate and deactivate cleanly', () async {
      f.services.extensions.register(
        _Ext(
          id: 'status-and-toolbar',
          contributions: [
            StatusItemContribution(id: 'status-and-toolbar.status', priority: 1, build: (_) => const SizedBox.shrink()),
            ToolbarButtonContribution(id: 'status-and-toolbar.btn', label: 'B', onPressed: () {}),
          ],
        ),
      );
      await f.services.extensions.activateAll();
      // Both contributions register through PanelRegistry.contributionsFor.
      expect(f.services.panels.contributionsFor(Slots.statusbar).whereType<StatusItemContribution>(), hasLength(1));
      await f.services.extensions.deactivate('status-and-toolbar');
      expect(f.services.panels.contributionsFor(Slots.statusbar).whereType<StatusItemContribution>(), isEmpty);
    });

    test('LayoutPresetContribution is accepted (no kernel-side wiring) and survives deactivate', () async {
      // LayoutPresetContribution is consumed by the default-layout
      // extension's own activate(); the manager's add/remove just hit
      // the no-op case branch.
      f.services.extensions.register(
        _Ext(
          id: 'preset-only',
          contributions: [const LayoutPresetContribution(id: 'preset-only.default', displayName: 'Preset only', slots: [])],
        ),
      );
      await f.services.extensions.activateAll();
      await f.services.extensions.deactivate('preset-only');
    });

    test('duplicate register() is a silent no-op (warns + skips)', () async {
      final ext = _Ext(id: 'dup');
      f.services.extensions.register(ext);
      f.services.extensions.register(ext); // second call → warn + skip
      expect(f.services.extensions.all.where((e) => e.id == 'dup'), hasLength(1));
    });

    test('activate of an unknown id is a silent no-op (warns + returns)', () async {
      await f.services.extensions.activate('nope.no-such');
      expect(f.services.extensions.isActivated('nope.no-such'), isFalse);
    });

    test('activate failure is caught and logged (extension survives)', () async {
      f.services.extensions.register(_Ext(id: 'throws-on-activate', onActivate: (_) async => throw StateError('kaboom')));
      await f.services.extensions.activateAll();
      expect(f.services.extensions.isActivated('throws-on-activate'), isFalse);
    });

    test('deactivate failure is caught and logged', () async {
      f.services.extensions.register(_Ext(id: 'throws-on-deactivate', onDeactivate: () async => throw StateError('kaboom')));
      await f.services.extensions.activateAll();
      expect(f.services.extensions.isActivated('throws-on-deactivate'), isTrue);
      await f.services.extensions.deactivate('throws-on-deactivate');
    });

    test('deactivating a CommandContribution removes its keybinding', () async {
      f.services.extensions.register(
        _Ext(
          id: 'with-bound-cmd',
          contributions: [
            CommandContribution(
              id: 'with-bound-cmd.cmd',
              command: 'bound.cmd',
              defaultBinding: 'ctrl+alt+j',
              run: (_) async => IpcResponse.ok(id: '', data: const {}),
            ),
          ],
        ),
      );
      await f.services.extensions.activateAll();
      expect(f.services.keybindings.commandFor(Keybinding.parse('ctrl+alt+j')), 'bound.cmd');
      await f.services.extensions.deactivate('with-bound-cmd');
      expect(f.services.keybindings.commandFor(Keybinding.parse('ctrl+alt+j')), isNull);
    });

    test('all getter yields every registered extension', () async {
      f.services.extensions.register(_Ext(id: 'a-iter'));
      f.services.extensions.register(_Ext(id: 'b-iter'));
      final ids = f.services.extensions.all.map((e) => e.id).toSet();
      expect(ids, containsAll(['a-iter', 'b-iter']));
    });

    test('extension context exposes every kernel service via passthrough getters', () async {
      ClideExtensionContext? captured;
      f.services.extensions.register(
        _Ext(
          id: 'ctx-capture',
          onActivate: (ctx) async {
            captured = ctx;
          },
        ),
      );
      await f.services.extensions.activateAll();
      final ctx = captured!;
      expect(ctx.id, 'ctx-capture');
      expect(ctx.log, same(f.services.log));
      expect(ctx.events, same(f.services.events));
      expect(ctx.messages, same(f.services.messages));
      expect(ctx.settings, same(f.services.settings));
      expect(ctx.theme, same(f.services.theme));
      expect(ctx.i18n, same(f.services.i18n));
      expect(ctx.panels, same(f.services.panels));
      expect(ctx.arrangement, same(f.services.arrangement));
      expect(ctx.commands, same(f.services.commands));
      expect(ctx.palette, same(f.services.palette));
      expect(ctx.clipboard, same(f.services.clipboard));
      expect(ctx.files, same(f.services.files));
      expect(ctx.notify, same(f.services.notify));
      expect(ctx.dialog, same(f.services.dialog));
      expect(ctx.tray, same(f.services.tray));
      expect(ctx.secrets, same(f.services.secrets));
      expect(ctx.os, same(f.services.os));
      expect(ctx.net, same(f.services.net));
      expect(ctx.focus, same(f.services.focus));
      expect(ctx.project, same(f.services.project));
      expect(ctx.ipc, same(f.services.ipc));
    });
  });
}

void _noop() {}
