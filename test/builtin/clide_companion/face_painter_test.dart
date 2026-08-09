import 'dart:ui' as ui;

import 'package:clide/builtin/clide_companion/src/face_painter.dart';
import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:clide/builtin/clide_companion/src/glyph_cache.dart';
import 'package:clide/builtin/clide_companion/src/rain_field.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

const _mono = 'JetBrainsMono';
const _size = Size(240, 160);

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  Future<SurfaceTokens> tokensFrom(WidgetTester tester) async {
    late SurfaceTokens tokens;
    await tester.pumpWidget(
      anchoredHarness(
        f,
        Builder(
          builder: (ctx) {
            tokens = ClideSettings.theme.of(ctx).surface;
            return const SizedBox();
          },
        ),
      ),
    );
    return tokens;
  }

  /// A field with rain actually in it, advanced to a steady state.
  RainField primedField({int target = 20}) {
    final field = RainField(columns: 20, rows: 14, seed: 5);
    for (var i = 0; i < 120; i++) {
      field.tick(1 / 30, targetStreams: target, speed: 9);
    }
    return field;
  }

  ClideFacePainter painter({
    required SurfaceTokens tokens,
    FaceState state = FaceState.idle,
    Gaze gaze = Gaze.none,
    RainField? field,
    GlyphCache? cache,
    ValueListenable<Duration>? clock,
    Duration? busyFor,
    double? lean,
    String fontFamily = _mono,
    double rainFontSize = 11,
  }) => ClideFacePainter(
    clock: clock ?? ValueNotifier(const Duration(milliseconds: 1200)),
    state: state,
    gaze: gaze,
    field: field ?? primedField(),
    cache: cache ?? GlyphCache(),
    tokens: tokens,
    fontFamily: fontFamily,
    busyFor: busyFor,
    lean: lean,
    rainFontSize: rainFontSize,
  );

  /// Rasterise and return the raw pixels. `toImage`/`toByteData` is real engine
  /// async, so every caller wraps this in `tester.runAsync` — on the fake test
  /// clock it never completes.
  Future<Uint8List> render(ClideFacePainter p, {Size size = _size}) async {
    final rec = ui.PictureRecorder();
    p.paint(ui.Canvas(rec, Offset.zero & size), size);
    final img = await rec.endRecording().toImage(size.width.round(), size.height.round());
    return (await img.toByteData())!.buffer.asUint8List();
  }

  Future<int> inkCount(ClideFacePainter p, {Size size = _size}) async {
    final px = await render(p, size: size);
    var n = 0;
    for (var i = 3; i < px.lengthInBytes; i += 4) {
      if (px[i] != 0) n++;
    }
    return n;
  }

  group('paints', () {
    testWidgets('every state draws something', (tester) async {
      final tokens = await tokensFrom(tester);
      for (final state in FaceState.values) {
        final n = await tester.runAsync(() => inkCount(painter(tokens: tokens, state: state)));
        expect(n, greaterThan(0), reason: '$state painted nothing');
      }
    });

    testWidgets('an empty size is a no-op rather than a crash', (tester) async {
      final tokens = await tokensFrom(tester);
      final rec = ui.PictureRecorder();
      expect(() => painter(tokens: tokens).paint(ui.Canvas(rec, Rect.zero), Size.zero), returnsNormally);
    });

    testWidgets('a degenerate field does not stop the face drawing', (tester) async {
      final tokens = await tokensFrom(tester);
      final n = await tester.runAsync(() => inkCount(painter(tokens: tokens, field: RainField(columns: 0, rows: 0, seed: 1))));
      expect(n, greaterThan(0));
    });
  });

  group('rain comes from the field, not the spec', () {
    testWidgets('an empty field draws no rain; a primed one does', (tester) async {
      // The painter draws whatever cells the field holds — it does not consult
      // spec.rainStreams. That number is the *target* the widget ticks the field
      // toward, so "error paints no rain" is enforced upstream by the spec
      // draining the field (tested in T-522), not by a branch in here. This is
      // the correct separation: the painter stays a pure function of the field.
      final tokens = await tokensFrom(tester);
      final empty = await tester.runAsync(() => render(painter(tokens: tokens, state: FaceState.error, field: RainField(columns: 20, rows: 14, seed: 5))));
      final primed = await tester.runAsync(() => render(painter(tokens: tokens, state: FaceState.error, field: primedField(target: 30))));
      expect(empty, isNot(equals(primed)), reason: 'the painter ignored the rain field');
    });

    testWidgets('error and effort render differently', (tester) async {
      final tokens = await tokensFrom(tester);
      final err = await tester.runAsync(() => render(painter(tokens: tokens, state: FaceState.error, field: RainField(columns: 20, rows: 14, seed: 5))));
      final eff = await tester.runAsync(
        () => render(painter(tokens: tokens, state: FaceState.effort, field: primedField(target: 40), busyFor: const Duration(seconds: 12))),
      );
      expect(err, isNot(equals(eff)));
    });
  });

  group('lean is visible in the output', () {
    testWidgets('left, centre and right produce different renders', (tester) async {
      // The lean is what makes the face read as attending to something. If the
      // painter dropped it these would be byte-identical.
      final tokens = await tokensFrom(tester);
      Future<Uint8List> at(double lean) =>
          render(painter(tokens: tokens, state: FaceState.pensive, lean: lean, field: RainField(columns: 20, rows: 14, seed: 5)));

      final left = await tester.runAsync(() => at(-8));
      final centre = await tester.runAsync(() => at(0));
      final right = await tester.runAsync(() => at(8));

      expect(left, isNot(equals(centre)), reason: 'lean -8 rendered identically to 0');
      expect(right, isNot(equals(centre)), reason: 'lean +8 rendered identically to 0');
      expect(left, isNot(equals(right)), reason: 'lean -8 rendered identically to +8');
    });

    testWidgets('gaze supplies the lean when none is passed', (tester) async {
      final tokens = await tokensFrom(tester);
      Future<Uint8List> at(Gaze g) => render(painter(tokens: tokens, state: FaceState.pensive, gaze: g, field: RainField(columns: 20, rows: 14, seed: 5)));

      final looking = await tester.runAsync(() => at(Gaze.left));
      final ahead = await tester.runAsync(() => at(Gaze.forward));
      expect(looking, isNot(equals(ahead)), reason: 'gaze did not drive the lean');
    });
  });

  group('wait cues appear only where they belong', () {
    testWidgets('the elapsed counter needs a busyFor', (tester) async {
      // busyFor is owned by Epic B. Without it there is nothing honest to show,
      // so the counter is absent rather than estimated.
      // Compared byte-wise rather than by counting non-transparent pixels: the
      // vignette is full-bleed, so nearly every pixel already has non-zero
      // alpha and an ink count cannot discriminate.
      final tokens = await tokensFrom(tester);
      final without = await tester.runAsync(() => render(painter(tokens: tokens, state: FaceState.effort, field: RainField(columns: 20, rows: 14, seed: 5))));
      final withCounter = await tester.runAsync(
        () => render(painter(tokens: tokens, state: FaceState.effort, field: RainField(columns: 20, rows: 14, seed: 5), busyFor: const Duration(seconds: 42))),
      );
      expect(withCounter, isNot(equals(without)), reason: 'busyFor did not add the counter');
    });
  });

  group('shouldRepaint', () {
    testWidgets('identical inputs do not repaint', (tester) async {
      final tokens = await tokensFrom(tester);
      final clock = ValueNotifier(const Duration(seconds: 1));
      final field = primedField();
      final cache = GlyphCache();
      ClideFacePainter make() => painter(tokens: tokens, clock: clock, field: field, cache: cache);
      expect(make().shouldRepaint(make()), isFalse);
    });

    testWidgets('each varying input triggers a repaint', (tester) async {
      final tokens = await tokensFrom(tester);
      final clock = ValueNotifier(const Duration(seconds: 1));
      final field = primedField();
      final cache = GlyphCache();
      ClideFacePainter base() => painter(tokens: tokens, clock: clock, field: field, cache: cache);
      ClideFacePainter vary({
        FaceState state = FaceState.idle,
        Gaze gaze = Gaze.none,
        double? lean,
        Duration? busyFor,
        double rainFontSize = 11,
        String fontFamily = _mono,
        RainField? field2,
        GlyphCache? cache2,
        ValueListenable<Duration>? clock2,
      }) => painter(
        tokens: tokens,
        clock: clock2 ?? clock,
        field: field2 ?? field,
        cache: cache2 ?? cache,
        state: state,
        gaze: gaze,
        lean: lean,
        busyFor: busyFor,
        rainFontSize: rainFontSize,
        fontFamily: fontFamily,
      );

      expect(base().shouldRepaint(vary(state: FaceState.effort)), isTrue, reason: 'state');
      expect(base().shouldRepaint(vary(gaze: Gaze.left)), isTrue, reason: 'gaze');
      expect(base().shouldRepaint(vary(lean: -8)), isTrue, reason: 'lean');
      expect(base().shouldRepaint(vary(busyFor: const Duration(seconds: 3))), isTrue, reason: 'busyFor');
      expect(base().shouldRepaint(vary(rainFontSize: 14)), isTrue, reason: 'rainFontSize');
      expect(base().shouldRepaint(vary(fontFamily: 'FiraMono')), isTrue, reason: 'fontFamily');
      expect(base().shouldRepaint(vary(field2: primedField())), isTrue, reason: 'field');
      expect(base().shouldRepaint(vary(cache2: GlyphCache())), isTrue, reason: 'cache');
      expect(base().shouldRepaint(vary(clock2: ValueNotifier(Duration.zero))), isTrue, reason: 'clock');
    });
  });

  group('the cache carries the drawing', () {
    testWidgets('painting many frames does not grow the cache without bound', (tester) async {
      // The whole point of T-523. A TextPainter-per-particle painter would grow
      // unbounded here, and a single frame's output would look identical.
      final tokens = await tokensFrom(tester);
      final cache = GlyphCache();
      final field = primedField(target: 40);
      final clock = ValueNotifier(Duration.zero);
      await tester.runAsync(() async {
        for (var frame = 0; frame < 120; frame++) {
          clock.value = Duration(milliseconds: frame * 33);
          final rec = ui.PictureRecorder();
          painter(tokens: tokens, clock: clock, field: field, cache: cache, state: FaceState.speaking).paint(ui.Canvas(rec, Offset.zero & _size), _size);
          rec.endRecording();
        }
      });
      expect(cache.length, greaterThan(0), reason: 'nothing was drawn through the cache');
      expect(cache.length, lessThanOrEqualTo(512));
    });
  });
}
