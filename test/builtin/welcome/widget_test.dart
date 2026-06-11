import 'package:clide/builtin/welcome/welcome.dart';
import 'package:clide/builtin/welcome/src/welcome_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('WelcomeExtension', () {
    late KernelFixture f;

    setUp(() async {
      f = await KernelFixture.create(
        i18nCatalogs: {
          'builtin.welcome': {
            const Locale('en', 'US'): const {
              'title': {'translation': 'clide'},
              'subtitle': {'translation': 'IDE for Claude Code CLI'},
              'open-project': {'translation': 'Open project'},
              'open-project.hint': {'translation': 'Pick a git repository'},
              'tab.title': {'translation': 'Welcome'},
            },
          },
        },
      );
    });

    tearDown(() async => f.dispose());

    test('contributes a workspace tab with an i18n title key', () {
      final ext = WelcomeExtension();
      final tabs = ext.contributions.whereType<TabContribution>().toList();
      expect(tabs, hasLength(1));
      expect(tabs.first.slot, Slots.workspace);
      expect(tabs.first.titleKey, 'tab.title');
      expect(tabs.first.i18nNamespace, ext.id);
    });

    testWidgets('WelcomeView renders title + subtitle + start actions', (tester) async {
      await tester.pumpWidget(harness(f, const WelcomeView()));
      expect(find.text('clide'), findsOneWidget);
      expect(find.text('IDE for Claude Code CLI'), findsOneWidget);
      expect(find.text('Open folder…'), findsOneWidget);
      // T-383: no advertised dead ends — these tiles were inert no-ops with
      // unregistered shortcuts; they return only with working flows.
      expect(find.text('Clone from git…'), findsNothing);
      expect(find.text('Start a Claude session'), findsNothing);
    });

    testWidgets('TIPS card renders when the viewport is tall enough', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(harness(f, const WelcomeView()));
      await tester.pumpAndSettle();
      expect(find.text('TIPS'), findsOneWidget);
      expect(find.text('Quick open'), findsOneWidget);
    });

    testWidgets('TIPS card is hidden when the viewport is short', (tester) async {
      tester.view.physicalSize = const Size(1200, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(harness(f, const WelcomeView()));
      await tester.pumpAndSettle();
      expect(find.text('TIPS'), findsNothing);
    });

    testWidgets('status line shows "checking…" before toolchain resolution', (tester) async {
      await tester.pumpWidget(harness(f, const WelcomeView()));
      expect(find.text('checking…'), findsOneWidget);
    });

    testWidgets('status line shows "application ok" when all tools resolved', (tester) async {
      f.services.toolchain.applyResolved(const ResolvedPaths(git: '/usr/bin/git', pql: '/usr/bin/pql', tmux: '/usr/bin/tmux', shell: '/bin/bash'));
      await tester.pumpWidget(harness(f, const WelcomeView()));
      await tester.pumpAndSettle();
      expect(find.text('application ok'), findsOneWidget);
    });

    testWidgets('status line lists missing tools when some are absent', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      f.services.toolchain.applyResolved(const ResolvedPaths(pql: '/usr/bin/pql'));
      await tester.pumpWidget(harness(f, const WelcomeView()));
      await tester.pumpAndSettle();
      expect(find.textContaining('git not found'), findsOneWidget);
      expect(find.textContaining('tmux not found'), findsOneWidget);
    });

    testWidgets('theme-name link fires the theme.pick command when tapped', (tester) async {
      var invocations = 0;
      f.services.commands.register(
        CommandContribution(
          id: 'theme.pick',
          command: 'theme.pick',
          title: 'Theme: Pick',
          run: (_) async {
            invocations++;
            return IpcResponse.ok(id: '', data: const {});
          },
        ),
      );
      await tester.pumpWidget(harness(f, const WelcomeView()));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('theme:'));
      await tester.pump();
      expect(invocations, 1);
    });

    testWidgets('Open folder tap kicks off the picker flow without throwing', (tester) async {
      await tester.pumpWidget(harness(f, const WelcomeView()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open folder…'));
      await tester.pumpAndSettle();
      // In the test harness, the platform channel returns null (no native
      // picker, no MissingPluginException), so the function returns
      // early without raising. The point is just to exercise the path.
      expect(tester.takeException(), isNull);
    });

    // T-122 ROOT CAUSE + FIX (2026-06-05): the strand was NOT in the recents
    // widgets — it was the seeding. SettingsStore.set does real file I/O
    // (writeAsString); awaiting settings.set + project.loadRecents INSIDE a
    // testWidgets body runs that I/O in fake-async, where the completion
    // callback is trapped and the await never returns (a +0 strand only
    // SIGKILL clears). Seeding inside tester.runAsync() runs it on the real
    // event loop, so the recents render fine. The bounded-vs-unbounded width
    // was a red herring — but a tight tree is still used here (the shared
    // harness()'s unbounded width breaks WelcomeView's Positioned status line
    // + Flexible rows independently).
    Widget tightWelcome() => Directionality(
      textDirection: TextDirection.ltr,
      child: ClideKernel(
        services: f.services,
        child: ClideTheme(
          controller: f.services.theme,
          child: const MediaQuery(
            data: MediaQueryData(size: Size(1200, 900)),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 1200, height: 900, child: WelcomeView()),
            ),
          ),
        ),
      ),
    );

    Future<void> seedRecents(WidgetTester tester, String json) async {
      // runAsync: real event loop, so SettingsStore's file I/O completes.
      await tester.runAsync(() async {
        await f.services.settings.set<String>('app.recentProjects', json);
        await f.services.project.loadRecents();
      });
    }

    testWidgets('recent rows render with branch + sticky variants (T-122)', (tester) async {
      await seedRecents(
        tester,
        '[{"path":"/tmp/alpha","name":"alpha","branch":"main","lastOpened":"2026-05-18T00:00:00.000Z","startupSticky":true},'
        '{"path":"/tmp/beta","name":"beta","lastOpened":"2026-05-18T00:00:00.000Z"}]',
      );
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(tightWelcome());
      await tester.pump();

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      expect(find.text('main'), findsOneWidget); // branch chip on the row that has one
      expect(find.byKey(const ValueKey('welcome.sticky./tmp/alpha')), findsOneWidget);
      expect(find.byKey(const ValueKey('welcome.sticky./tmp/beta')), findsOneWidget);
    });

    testWidgets('sticky-startup toggle flips when tapped (T-115/T-122)', (tester) async {
      await seedRecents(tester, '[{"path":"/tmp/clide-fixture","name":"clide-fixture","lastOpened":"2026-05-18T00:00:00.000Z"}]');
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(tightWelcome());
      await tester.pump();
      expect(find.text('clide-fixture'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('welcome.sticky./tmp/clide-fixture')), warnIfMissed: false);
      await tester.pump();
      expect(f.services.project.recents.first.startupSticky, isTrue);
    });

    testWidgets('tapping a recent row kicks off _openRecent without throwing (T-122)', (tester) async {
      await seedRecents(tester, '[{"path":"/tmp/clide-fixture","name":"clide-fixture","lastOpened":"2026-05-18T00:00:00.000Z"}]');
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(tightWelcome());
      await tester.pump();
      // /tmp/clide-fixture is not a git repo → project.open returns false,
      // no tab activation, no throw. Just exercises the _openRecent path.
      await tester.runAsync(() async {
        await tester.tap(find.text('clide-fixture'), warnIfMissed: false);
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Open folder opens the fallback dialog when the picker throws MissingPluginException', (tester) async {
      // Pre-register a mock that throws — emulating a platform without
      // native picker support.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('clide/window'), (call) async {
        if (call.method == 'pickDirectory') {
          throw MissingPluginException();
        }
        return null;
      });
      await tester.pumpWidget(harness(f, const WelcomeView()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open folder…'));
      await tester.pumpAndSettle();
      expect(f.services.dialog.isOpen, isTrue);
      f.services.dialog.dismiss();
      await tester.pumpAndSettle();
    });
  });
}
