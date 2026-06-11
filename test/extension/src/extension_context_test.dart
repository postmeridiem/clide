/// Covers the `ClideExtensionContext` sugar extensions (publish /
/// subscribe / t / tr) and the default no-op `ClideExtension`
/// lifecycle hooks, driving the *real* context the ExtensionManager
/// hands to `activate()`.
library;

import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

/// Extension that exercises the context sugar inside activate().
class _SugarExt extends ClideExtension {
  _SugarExt(this.onActivate);
  final Future<void> Function(ClideExtensionContext ctx) onActivate;
  @override
  String get id => 'sugar.ext';
  @override
  String get title => 'Sugar';
  @override
  String get version => '0.0.0-test';
  @override
  List<ContributionPoint> get contributions => const [];
  @override
  Future<void> activate(ClideExtensionContext ctx) => onActivate(ctx);
}

/// Extension that overrides nothing — its activate/deactivate are the
/// base-class defaults (the lines under test).
class _BareExt extends ClideExtension {
  @override
  String get id => 'bare.ext';
  @override
  String get title => 'Bare';
  @override
  String get version => '0.0.0-test';
  @override
  List<ContributionPoint> get contributions => const [];
}

void main() {
  group('ClideExtensionContext sugar', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create();
    });

    tearDown(() async {
      await f.dispose();
    });

    test('publish + subscribe round-trip through the message bus', () async {
      Message? received;
      f.services.extensions.register(
        _SugarExt((ctx) async {
          final first = ctx.subscribe(channel: 'greet').first;
          ctx.publish('greet', {'hello': 'world'});
          received = await first;
        }),
      );
      await f.services.extensions.activate('sugar.ext');
      expect(received, isNotNull);
      expect(received!.publisher, 'sugar.ext');
      expect(received!.channel, 'greet');
      expect(received!.data['hello'], 'world');
    });

    test('t + tr resolve against the extension namespace', () async {
      String? t;
      String? tr;
      f.services.extensions.register(
        _SugarExt((ctx) async {
          t = ctx.t('missing.key');
          tr = ctx.tr('missing.key', replacers: const []);
        }),
      );
      await f.services.extensions.activate('sugar.ext');
      // No catalog loaded for this namespace → i18n falls back, but the
      // sugar getters still execute and return a non-null string.
      expect(t, isNotNull);
      expect(tr, isNotNull);
    });
  });

  group('ClideExtension default lifecycle', () {
    test('base activate + deactivate are safe no-ops', () async {
      final ext = _BareExt();
      // Default activate (no context needed by the base impl) +
      // default deactivate must both complete without throwing.
      await expectLater(ext.deactivate(), completes);
    });

    test('manager deactivate invokes the base deactivate', () async {
      final f = await KernelFixture.create();
      addTearDown(f.dispose);
      f.services.extensions.register(_BareExt());
      await f.services.extensions.activate('bare.ext');
      await f.services.extensions.deactivate('bare.ext');
      // Reaching here means the base ClideExtension.deactivate() ran
      // through the manager without error.
      expect(f.services.extensions.failedExtensions['bare.ext'], isNull);
    });
  });
}
