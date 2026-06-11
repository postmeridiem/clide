/// Tests for the `panel.*` command handlers (T-119).
///
/// Uses an in-memory [PanelResizer] fake so the dispatch surface can
/// be exercised under `dart test` without pulling Flutter into the
/// build (the live kernel resizer wraps `LayoutArrangement`, which is
/// Flutter-bound; tests for that live in
/// `test/kernel/src/panels/arrangement_test.dart`).
library;

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/panel_commands.dart';
import 'package:test/test.dart';

void main() {
  group('panel.resize dispatch', () {
    late DaemonDispatcher dispatcher;
    late _FakeResizer resizer;

    setUp(() {
      resizer = _FakeResizer(slots: {'sidebar': 200, 'context': 240, 'workspace': 800}, editorRatio: 0.35);
      dispatcher = DaemonDispatcher();
      registerPanelCommands(dispatcher, resizer);
    });

    Future<IpcResponse> call(Map<String, Object?> args) {
      return dispatcher.dispatch(IpcRequest(id: '1', cmd: 'panel.resize', args: args));
    }

    test('rejects a request with no slot', () async {
      final r = await call(const {'to': 220});
      expect(r.ok, isFalse);
      expect(r.error!.kind, 'user_error');
      expect(r.error!.message, contains('slot'));
    });

    test('rejects a request with neither `to` nor `by`', () async {
      final r = await call(const {'slot': 'sidebar'});
      expect(r.ok, isFalse);
      expect(r.error!.kind, 'user_error');
      expect(r.error!.message, contains('to'));
      expect(r.error!.message, contains('by'));
    });

    test('rejects a request with both `to` and `by`', () async {
      final r = await call(const {'slot': 'sidebar', 'to': 200, 'by': 10});
      expect(r.ok, isFalse);
      expect(r.error!.kind, 'user_error');
      expect(r.error!.message, contains('only one'));
    });

    test('rejects a non-numeric `to`', () async {
      final r = await call(const {'slot': 'sidebar', 'to': 'lots'});
      expect(r.ok, isFalse);
      expect(r.error!.kind, 'user_error');
      expect(r.error!.message, contains('number'));
    });

    test('rejects an unknown slot with not-found', () async {
      final r = await call(const {'slot': 'nonsense', 'to': 100});
      expect(r.ok, isFalse);
      expect(r.error!.kind, 'not_found');
      expect(r.error!.message, contains('nonsense'));
    });

    test('absolute `to` sets the slot size and echoes the result', () async {
      final r = await call(const {'slot': 'sidebar', 'to': 320});
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['slot'], 'sidebar');
      expect(r.data['size'], 320);
      expect(resizer.slots['sidebar'], 320);
    });

    test('relative `by` bumps the slot through PanelResizer.bumpSlotSize', () async {
      final r = await call(const {'slot': 'sidebar', 'by': 25});
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(resizer.slots['sidebar'], 200 + 25);
      expect(resizer.lastBumpSlot, 'sidebar');
      expect(resizer.lastBumpDelta, 25);
    });

    test('editor slot routes to setEditorRatio', () async {
      final r = await call(const {'slot': 'editor', 'to': 0.55});
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['ratio'], 0.55);
      expect(resizer.editorRatio, 0.55);
    });

    test('editor slot with `by` routes to bumpEditorRatio', () async {
      final r = await call(const {'slot': 'editor', 'by': 0.1});
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(resizer.editorRatio, closeTo(0.45, 1e-9));
    });

    group('argv-translator shape', () {
      test('positional[0] supplies the slot and flags carry to/by as strings', () async {
        final r = await call(const {
          'positional': ['sidebar'],
          'flags': {'to': '275'},
        });
        expect(r.ok, isTrue, reason: r.error?.message);
        expect(resizer.slots['sidebar'], 275);
      });

      test('argv shape `by` parses to a delta', () async {
        final r = await call(const {
          'positional': ['context'],
          'flags': {'by': '-30'},
        });
        expect(r.ok, isTrue, reason: r.error?.message);
        expect(resizer.lastBumpSlot, 'context');
        expect(resizer.lastBumpDelta, -30);
      });

      test('argv shape with neither flag still surfaces a user error', () async {
        final r = await call(const {
          'positional': ['sidebar'],
          'flags': <String, Object?>{},
        });
        expect(r.ok, isFalse);
        expect(r.error!.kind, 'user_error');
      });
    });
  });
}

class _FakeResizer implements PanelResizer {
  _FakeResizer({required this.slots, required this.editorRatio});

  final Map<String, double> slots;
  double editorRatio;

  String? lastBumpSlot;
  double? lastBumpDelta;

  @override
  bool setSlotSize(String slot, double size) {
    if (!slots.containsKey(slot)) return false;
    slots[slot] = size;
    return true;
  }

  @override
  bool bumpSlotSize(String slot, double rawDelta) {
    if (!slots.containsKey(slot)) return false;
    lastBumpSlot = slot;
    lastBumpDelta = rawDelta;
    slots[slot] = slots[slot]! + rawDelta;
    return true;
  }

  @override
  void setEditorRatio(double ratio) {
    editorRatio = ratio;
  }

  @override
  void bumpEditorRatio(double delta) {
    editorRatio += delta;
  }

  @override
  double? currentSlotSize(String slot) => slots[slot];

  @override
  double get currentEditorRatio => editorRatio;
}
