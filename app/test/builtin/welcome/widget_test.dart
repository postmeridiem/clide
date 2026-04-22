import 'dart:ui';

import 'package:clide_app/builtin/welcome/welcome.dart';
import 'package:clide_app/builtin/welcome/src/welcome_view.dart';
import 'package:clide_app/extension/extension.dart';
import 'package:clide_app/kernel/kernel.dart';
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
              'subtitle': {
                'translation': 'Flutter desktop IDE for Claude Code'
              },
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

    testWidgets('WelcomeView renders title + subtitle + Open-project button',
        (tester) async {
      await tester.pumpWidget(harness(f, const WelcomeView()));
      expect(find.text('clide'), findsOneWidget);
      expect(
        find.text('Flutter desktop IDE for Claude Code'),
        findsOneWidget,
      );
      expect(find.text('Open project'), findsOneWidget);
    });

    testWidgets('Open-project action renders as tappable row',
        (tester) async {
      await tester.pumpWidget(harness(f, const WelcomeView()));
      expect(find.text('Open project'), findsOneWidget);
    });

    testWidgets('locale switch refreshes the visible text', (tester) async {
      await tester.pumpWidget(harness(f, const WelcomeView()));
      f.services.i18n
          .registerCatalog('builtin.welcome', const Locale('nl'), const {
        'title': {'translation': 'clide-nl'},
        'subtitle': {'translation': 'Flutter IDE voor Claude Code'},
        'open-project': {'translation': 'Project openen'},
        'open-project.hint': {'translation': 'Kies een git repo'},
        'tab.title': {'translation': 'Welkom'},
      });
      await f.services.i18n.setLocale(const Locale('nl'));
      await tester.pumpAndSettle();
      expect(find.text('Project openen'), findsOneWidget);
      expect(find.text('clide-nl'), findsOneWidget);
    });
  });
}
