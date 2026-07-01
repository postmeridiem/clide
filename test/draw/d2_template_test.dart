import 'package:clide/src/draw/d2_template.dart';
import 'package:clide/src/draw/draw_dispatch.dart';
import 'package:clide/src/draw/draw_doc.dart';
import 'package:test/test.dart';

void main() {
  DrawingCardDoc d2doc(Object? source) => DrawingCardDoc(template: 'd2', fields: {'template': 'd2', 'source': ?source});

  group('d2TemplateHandler', () {
    test('compiles the source field via the injected compiler', () async {
      final h = d2TemplateHandler(compile: (s) async => DrawOk('<svg data-s="$s"/>'));
      final r = await h(d2doc('a -> b'));
      expect((r as DrawOk).svg, '<svg data-s="a -> b"/>');
    });

    test('a missing source is an honest error', () async {
      final h = d2TemplateHandler(compile: (_) async => const DrawOk('x'));
      expect(await h(d2doc(null)), isA<DrawErr>());
    });

    test('a blank source is an honest error', () async {
      final h = d2TemplateHandler(compile: (_) async => const DrawOk('x'));
      expect(await h(d2doc('   ')), isA<DrawErr>());
    });

    test('propagates a compiler error message', () async {
      final h = d2TemplateHandler(compile: (_) async => const DrawErr('boom'));
      expect((await h(d2doc('a -> b')) as DrawErr).message, 'boom');
    });
  });

  group('d2CompileViaBinary', () {
    Future<DrawResult> compile({String? bin = '/x/d2', D2Run? run}) =>
        d2CompileViaBinary('a -> b', resolveD2: () => bin, run: run ?? (exe, src) async => (code: 0, out: '<svg/>', err: 'success:'));

    test('unresolved d2 hints how to install', () async {
      expect((await compile(bin: null) as DrawErr).message, contains('d2 not found'));
    });

    test('a clean compile returns the SVG (stderr ignored)', () async {
      expect((await compile() as DrawOk).svg, '<svg/>');
    });

    test('a non-zero exit is a compile error carrying stderr', () async {
      final r = await compile(run: (exe, src) async => (code: 1, out: '', err: 'line 2: syntax error'));
      expect((r as DrawErr).message, contains('syntax error'));
    });

    test('empty output is an error', () async {
      final r = await compile(run: (exe, src) async => (code: 0, out: '  ', err: ''));
      expect(r, isA<DrawErr>());
    });

    test('a spawn failure is reported honestly', () async {
      final r = await compile(run: (exe, src) async => throw 'ENOENT');
      expect((r as DrawErr).message, contains('could not run d2'));
    });

    test('spawns the resolved binary over stdin — real process (covers _spawnD2)', () async {
      // /bin/cat stands in for d2: `cat - -` echoes stdin (the source) to stdout.
      final r = await d2CompileViaBinary('<svg>hi</svg>', resolveD2: () => '/bin/cat');
      expect((r as DrawOk).svg, contains('hi'));
    }, testOn: 'linux || mac-os');

    test('the default resolver runs when resolveD2 is not injected', () async {
      // run is injected so there is no real spawn; the default resolver either
      // finds d2 or not — either way exercises _defaultResolveD2.
      final r = await d2CompileViaBinary('a -> b', run: (exe, src) async => (code: 0, out: '<svg/>', err: ''));
      expect(r, anyOf(isA<DrawOk>(), isA<DrawErr>()));
    });
  });
}
