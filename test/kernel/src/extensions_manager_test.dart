import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

/// Minimal no-op extension used as a test actor.
class _Ext extends ClideExtension {
  _Ext({
    required this.id,
    this.dependsOn = const [],
    this.contributions = const [],
    this.onActivate,
    this.onDeactivate,
  });

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
        ..register(_Ext(
          id: 'a',
          onActivate: (_) async => order.add('a'),
        ))
        ..register(_Ext(
          id: 'b',
          dependsOn: const ['a'],
          onActivate: (_) async => order.add('b'),
        ))
        ..register(_Ext(
          id: 'c',
          dependsOn: const ['b'],
          onActivate: (_) async => order.add('c'),
        ));
      await f.services.extensions.activateAll();
      expect(order, ['a', 'b', 'c']);
    });

    test('missing dep skips the dependent with a warning', () async {
      final order = <String>[];
      f.services.extensions.register(_Ext(
        id: 'needs-missing',
        dependsOn: const ['does.not.exist'],
        onActivate: (_) async => order.add('needs-missing'),
      ));
      await f.services.extensions.activateAll();
      expect(order, isEmpty);
      expect(f.services.extensions.isActivated('needs-missing'), false);
    });

    test('contribution points wire into panel registry on activate', () async {
      f.services.extensions.register(_Ext(
        id: 'with-tab',
        contributions: [
          TabContribution(
            id: 'with-tab.view',
            slot: Slots.workspace,
            title: 'T',
            build: (_) => const SizedBox.shrink(),
          ),
        ],
      ));
      await f.services.extensions.activateAll();
      expect(
        f.services.panels.tabsFor(Slots.workspace).map((t) => t.id),
        ['with-tab.view'],
      );
    });

    test('deactivate removes contributions from the registry', () async {
      f.services.extensions.register(_Ext(
        id: 'ephemeral',
        contributions: [
          TabContribution(
            id: 'ephemeral.view',
            slot: Slots.workspace,
            title: 'T',
            build: (_) => const SizedBox.shrink(),
          ),
        ],
      ));
      await f.services.extensions.activateAll();
      expect(f.services.panels.tabsFor(Slots.workspace), hasLength(1));
      await f.services.extensions.deactivate('ephemeral');
      expect(f.services.panels.tabsFor(Slots.workspace), isEmpty);
    });

    test('CommandContribution registers + default binding is bound', () async {
      f.services.extensions.register(_Ext(
        id: 'has-cmd',
        contributions: [
          CommandContribution(
            id: 'c',
            command: 'test.cmd',
            defaultBinding: 'ctrl+alt+k',
            run: (_) async => IpcResponse.ok(id: '', data: const {}),
          ),
        ],
      ));
      await f.services.extensions.activateAll();
      expect(f.services.commands.get('test.cmd'), isNotNull);
      expect(
        f.services.keybindings.commandFor(Keybinding.parse('ctrl+alt+k')),
        'test.cmd',
      );
    });

    test('setEnabled=false deactivates; =true reactivates', () async {
      final order = <String>[];
      f.services.extensions.register(_Ext(
        id: 'toggle',
        onActivate: (_) async => order.add('on'),
        onDeactivate: () async => order.add('off'),
      ));
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
      final s1 = f.services.events
          .on<ExtensionActivated>()
          .listen((e) => activated.add(e.id));
      final s2 = f.services.events
          .on<ExtensionDeactivated>()
          .listen((e) => deactivated.add(e.id));
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
  });
}
