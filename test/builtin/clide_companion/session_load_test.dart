import 'package:clide/builtin/clide_companion/src/session_load.dart';
import 'package:test/test.dart';

void main() {
  group('the load ladder', () {
    test('density is ordered absent < calm < working', () {
      double d(SessionLoad l) => loadSpecFor(l).rainDensity;
      expect(d(SessionLoad.absent), lessThan(d(SessionLoad.calm)));
      expect(d(SessionLoad.calm), lessThan(d(SessionLoad.working)));
    });

    test('absent stops the rain completely', () {
      // The visible half of the power-ladder contract (D-107 commitment 4): a
      // dead session must not keep animating, and a zero target is what lets the
      // field drain and the render loop park.
      expect(loadSpecFor(SessionLoad.absent).rainDensity, 0);
      expect(loadSpecFor(SessionLoad.absent).rainSpeed, 0);
    });

    test('every live level has moving rain', () {
      for (final load in SessionLoad.values.where((l) => l != SessionLoad.absent)) {
        expect(loadSpecFor(load).rainDensity, greaterThan(0), reason: '$load has no rain');
        expect(loadSpecFor(load).rainSpeed, greaterThan(0), reason: '$load has stalled rain');
      }
    });
  });

  group('density scales with the grid', () {
    // The bug this shape replaced: an absolute count was 63% column occupancy at
    // the 420px default and 26% at the 1000px maximum — one state looking like
    // two (T-533). Carried across the T-537 split intact.
    const narrow = 33; // 220px
    const wide = 151; // 1000px

    test('a level reads the same at any panel width', () {
      for (final load in SessionLoad.values.where((l) => l != SessionLoad.absent)) {
        final spec = loadSpecFor(load);
        expect(spec.streamsFor(wide), greaterThan(spec.streamsFor(narrow)), reason: '$load does not scale');
        expect(spec.streamsFor(wide) / wide, closeTo(spec.streamsFor(narrow) / narrow, 0.05), reason: '$load occupancy drifts with width');
      }
    });

    test('working fills roughly one stream per column', () {
      expect(loadSpecFor(SessionLoad.working).streamsFor(151), 151);
      expect(loadSpecFor(SessionLoad.working).streamsFor(33), 33);
    });

    test('a degenerate grid asks for no streams', () {
      for (final load in SessionLoad.values) {
        expect(loadSpecFor(load).streamsFor(0), 0);
      }
    });
  });

  group('shape', () {
    test('is coarse on purpose', () {
      // busyStream is a boolean. Gradations invented from a signal that has none
      // would be a gauge that looks precise and is not — the thing D-107 rules
      // out when it bans fake progress bars. Adding a level means finding a real
      // signal for it first.
      expect(SessionLoad.values, [SessionLoad.absent, SessionLoad.calm, SessionLoad.working]);
    });
  });
}
