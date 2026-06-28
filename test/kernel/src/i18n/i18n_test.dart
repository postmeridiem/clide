import 'dart:ui';

import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fills fframe's test gap — every path through the lookup matrix is
/// exercised here.
void main() {
  group('I18n lookup & fallback', () {
    late Logger log;

    setUp(() {
      log = Logger(minLevel: LogLevel.error); // silence warnings in tests
    });

    I18n build({
      required Map<String, Map<Locale, Map<String, Object?>>> catalogs,
      Locale initial = const Locale('en', 'US'),
      Locale defaultLocale = const Locale('en', 'US'),
    }) {
      final loader = InMemoryCatalogLoader(catalogs);
      final i = I18n(
        loader: loader,
        log: log,
        defaultLocale: defaultLocale,
        initialLocale: initial,
        availableLocales: const [Locale('en', 'US'), Locale('nl', 'NL')],
      );
      return i;
    }

    test('locale getters reflect constructor arguments', () {
      final i = build(catalogs: const {}, initial: const Locale('nl', 'NL'), defaultLocale: const Locale('en', 'US'));
      expect(i.currentLocale, const Locale('nl', 'NL'));
      expect(i.defaultLocale, const Locale('en', 'US'));
      expect(i.availableLocales, [const Locale('en', 'US'), const Locale('nl', 'NL')]);
    });

    test('missing key with placeholder returns placeholder', () async {
      final i = build(catalogs: const {});
      await i.ensureNamespaceLoaded('builtin.x');
      expect(i.string('missing', namespace: 'builtin.x', placeholder: 'fallback'), 'fallback');
    });

    test('missing key with null placeholder returns the key', () async {
      final i = build(catalogs: const {});
      await i.ensureNamespaceLoaded('builtin.x');
      expect(i.string('foo.bar', namespace: 'builtin.x'), 'foo.bar');
    });

    test('unknown namespace still returns placeholder (no crash)', () {
      final i = build(catalogs: const {});
      expect(i.string('k', namespace: 'not.registered', placeholder: 'fb'), 'fb');
    });

    test('exact locale hit beats fallback', () async {
      final i = build(
        catalogs: {
          'builtin.x': {
            const Locale('en', 'US'): {
              'greet': {'translation': 'Hello'},
            },
            const Locale('en'): {
              'greet': {'translation': 'Hi'},
            },
          },
        },
      );
      await i.ensureNamespaceLoaded('builtin.x');
      expect(i.string('greet', namespace: 'builtin.x', placeholder: 'fb'), 'Hello');
    });

    test('language-only locale hit falls through from exact', () async {
      final i = build(
        catalogs: {
          'builtin.x': {
            const Locale('nl'): {
              'greet': {'translation': 'Hoi'},
            },
          },
        },
        initial: const Locale('nl', 'NL'),
      );
      await i.ensureNamespaceLoaded('builtin.x');
      expect(i.string('greet', namespace: 'builtin.x', placeholder: 'fb'), 'Hoi');
    });

    test('falls through to default-locale when current locale is empty', () async {
      final i = build(
        catalogs: {
          'builtin.x': {
            const Locale('en', 'US'): {
              'greet': {'translation': 'Hello'},
            },
          },
        },
        initial: const Locale('nl', 'NL'),
      );
      await i.ensureNamespaceLoaded('builtin.x');
      expect(i.string('greet', namespace: 'builtin.x', placeholder: 'fb'), 'Hello');
    });

    test('interpolation replaces all replacers; missing ones silent', () async {
      final i = build(
        catalogs: {
          'builtin.x': {
            const Locale('en', 'US'): {
              'welcome': {'translation': 'Hi {name} at {path}'},
            },
          },
        },
      );
      await i.ensureNamespaceLoaded('builtin.x');
      expect(
        i.interpolated(
          'welcome',
          namespace: 'builtin.x',
          placeholder: 'Hi {name} at {path}',
          replacers: const [
            I18nReplacer(from: '{name}', replace: 'Claude'),
            // {path} deliberately absent
          ],
        ),
        'Hi Claude at {path}',
      );
    });

    test('namespace isolation — same key, different values', () async {
      final i = build(
        catalogs: {
          'a': {
            const Locale('en', 'US'): {
              'k': {'translation': 'A'},
            },
          },
          'b': {
            const Locale('en', 'US'): {
              'k': {'translation': 'B'},
            },
          },
        },
      );
      await i.ensureNamespaceLoaded('a');
      await i.ensureNamespaceLoaded('b');
      expect(i.string('k', namespace: 'a', placeholder: '-'), 'A');
      expect(i.string('k', namespace: 'b', placeholder: '-'), 'B');
    });

    test('setLocale refreshes cached namespaces and notifies listeners', () async {
      final i = build(
        catalogs: {
          'x': {
            const Locale('en', 'US'): {
              'k': {'translation': 'Hello'},
            },
            const Locale('nl'): {
              'k': {'translation': 'Hallo'},
            },
          },
        },
      );
      await i.ensureNamespaceLoaded('x');
      var notified = 0;
      i.addListener(() => notified++);
      await i.setLocale(const Locale('nl'));
      expect(notified, greaterThanOrEqualTo(1));
      expect(i.string('k', namespace: 'x', placeholder: '-'), 'Hallo');
    });

    test('registerCatalog merges third-party catalog', () async {
      final i = build(catalogs: const {});
      i.registerCatalog('ext.linear', const Locale('en', 'US'), const {
        'issue.title': {'translation': 'Issues'},
      });
      expect(i.string('issue.title', namespace: 'ext.linear', placeholder: '-'), 'Issues');
    });

    test('unregisterCatalog forgets a namespace', () async {
      final i = build(catalogs: const {});
      i.registerCatalog('ext.x', const Locale('en', 'US'), const {
        'k': {'translation': 'v'},
      });
      expect(i.string('k', namespace: 'ext.x', placeholder: '-'), 'v');
      i.unregisterCatalog('ext.x');
      expect(i.string('k', namespace: 'ext.x', placeholder: '-'), '-');
    });

    test('plain-string shape (no nested translation) is accepted', () async {
      // Forward-compat: if a catalog later switches to `"k": "v"`
      // instead of `"k": {"translation": "v"}`, lookup still works.
      final i = build(
        catalogs: {
          'x': {
            const Locale('en', 'US'): {'k': 'direct'},
          },
        },
      );
      await i.ensureNamespaceLoaded('x');
      expect(i.string('k', namespace: 'x', placeholder: '-'), 'direct');
    });
  });

  group('FallbackChain.resolve', () {
    test('ordering: exact, lang, default, default-lang', () {
      final chain = const FallbackChain(current: Locale('nl', 'NL'), defaultLocale: Locale('en', 'US')).resolve();
      expect(chain.map((l) => l.toString()).toList(), ['nl_NL', 'nl', 'en_US', 'en']);
    });

    test('deduplicates when current == default', () {
      final chain = const FallbackChain(current: Locale('en', 'US'), defaultLocale: Locale('en', 'US')).resolve();
      expect(chain, ['en_US', 'en'].map((_) => isA<Locale>()));
      expect(chain.length, 2);
    });

    test('filenameSuffix lowercases + omits empty country', () {
      expect(FallbackChain.filenameSuffix(const Locale('en', 'US')), 'en_us');
      expect(FallbackChain.filenameSuffix(const Locale('en')), 'en');
    });
  });

  // T-493: open-ended lookups (tool display names like `tool.name.Bash`,
  // `tool.name.ScheduleWakeup`, MCP tools) intentionally miss and fall back to
  // the raw name, so they must not spam the warn log.
  group('warnIfMissing (T-493)', () {
    I18n withCapture(List<Object> warns) => I18n(
      loader: InMemoryCatalogLoader(const {}),
      log: Logger(minLevel: LogLevel.warn, sinks: [warns.add]),
      defaultLocale: const Locale('en', 'US'),
    );

    test('a real gap warns by default, but warnIfMissing:false stays silent', () async {
      final warns = <Object>[];
      final i = withCapture(warns);
      await i.ensureNamespaceLoaded('builtin.x');

      expect(i.string('missing', namespace: 'builtin.x', placeholder: 'fb'), 'fb');
      expect(warns, isNotEmpty, reason: 'a fixed UI string gap should still warn');

      warns.clear();
      expect(i.string('tool.name.Bash', namespace: 'builtin.x', placeholder: 'Bash', warnIfMissing: false), 'Bash');
      expect(warns, isEmpty, reason: 'open-ended tool-name lookups stay quiet');
    });

    test('warnIfMissing:false also silences an unregistered namespace', () {
      final warns = <Object>[];
      expect(withCapture(warns).string('k', namespace: 'unregistered', placeholder: 'p', warnIfMissing: false), 'p');
      expect(warns, isEmpty);
    });
  });
}
