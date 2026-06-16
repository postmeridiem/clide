/// Unit tests for the Vim ex command-line (T-407): the [parseExCommand]
/// grammar, the [ExLineController] open/close/flash state, and the
/// editor-targeted executor functions (which no-op when no buffer is active).
library;

import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ipc.dart';

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);

void main() {
  group('parseExCommand', () {
    test('empty (and bare colon) is a no-op', () {
      expect(parseExCommand(''), isA<ExNoop>());
      expect(parseExCommand('  '), isA<ExNoop>());
      expect(parseExCommand(':'), isA<ExNoop>());
    });

    test('write / quit / write-quit and their aliases', () {
      expect(parseExCommand('w'), isA<ExWrite>());
      expect(parseExCommand('q'), isA<ExQuit>());
      expect(parseExCommand('q!'), isA<ExQuit>());
      expect(parseExCommand('wq'), isA<ExWriteQuit>());
      expect(parseExCommand('wq!'), isA<ExWriteQuit>());
      expect(parseExCommand('x'), isA<ExWriteQuit>());
      expect(parseExCommand('x!'), isA<ExWriteQuit>());
    });

    test('a leading colon is tolerated', () {
      expect(parseExCommand(':w'), isA<ExWrite>());
      expect(parseExCommand(':q'), isA<ExQuit>());
    });

    test('edit seeds quick-open with the rest of the line', () {
      expect(parseExCommand('e'), const ExEdit(''));
      expect(parseExCommand('e lib/main.dart'), const ExEdit('lib/main.dart'));
      expect(parseExCommand('e  spaced  '), const ExEdit('spaced'));
    });

    test('a positive integer is a goto-line', () {
      expect(parseExCommand('1'), const ExGoto(1));
      expect(parseExCommand('42'), const ExGoto(42));
    });

    test('zero, negatives and junk are unknown', () {
      expect(parseExCommand('0'), isA<ExUnknown>());
      expect(parseExCommand('-3'), isA<ExUnknown>());
      expect(parseExCommand('wat'), isA<ExUnknown>());
      expect(parseExCommand('e'), isNot(isA<ExUnknown>())); // guard: e is ExEdit
    });
  });

  group('ExLineController', () {
    late ExLineController c;
    setUp(() => c = ExLineController());
    tearDown(() => c.dispose());

    test('open clears input and flips isOpen; close resets', () {
      var notifications = 0;
      c.addListener(() => notifications++);
      c.setInput('stale');
      c.open();
      expect(c.isOpen, isTrue);
      expect(c.input, isEmpty);
      c.setInput('w');
      expect(c.input, 'w');
      c.close();
      expect(c.isOpen, isFalse);
      expect(c.input, isEmpty);
      expect(notifications, greaterThan(0));
    });

    test('open is idempotent and does not re-clear a second time', () {
      c.open();
      c.setInput('w');
      c.open(); // no-op
      expect(c.input, 'w');
    });

    test('flashInvalid bumps the nonce monotonically', () {
      final start = c.invalidNonce;
      c.flashInvalid();
      c.flashInvalid();
      expect(c.invalidNonce, start + 2);
    });
  });

  group('executors', () {
    late DaemonBus bus;
    late FakeDaemonClient ipc;
    late List<String> calls;

    setUp(() {
      bus = DaemonBus();
      ipc = FakeDaemonClient(log: Logger(), events: bus);
      calls = [];
    });
    tearDown(() => bus.dispose());

    void record(String cmd, [Map<String, Object?> data = const {}]) {
      ipc.stub(cmd, (a) async {
        calls.add(cmd);
        return _ok(data);
      });
    }

    test(':w saves the active buffer', () async {
      record('editor.save');
      await exWriteActive(ipc);
      expect(calls, ['editor.save']);
    });

    test(':q resolves the active id then closes it', () async {
      ipc.stub('editor.active', (_) async {
        calls.add('editor.active');
        return _ok({
          'active': {'id': 'b_7'},
        });
      });
      ipc.stub('editor.close', (a) async {
        calls.add('editor.close:${a['id']}');
        return _ok({});
      });
      await exQuitActive(ipc);
      expect(calls, ['editor.active', 'editor.close:b_7']);
    });

    test(':q is a no-op with no active buffer', () async {
      ipc.stub('editor.active', (_) async => _ok({'active': null}));
      record('editor.close');
      await exQuitActive(ipc);
      expect(calls, isEmpty); // never reached editor.close
    });

    test(':wq saves then closes the active tab', () async {
      ipc.stub(
        'editor.active',
        (_) async => _ok({
          'active': {'id': 'b_3'},
        }),
      );
      ipc.stub('editor.save', (a) async {
        calls.add('save:${a['id']}');
        return _ok({});
      });
      ipc.stub('editor.close', (a) async {
        calls.add('close:${a['id']}');
        return _ok({});
      });
      await exWriteQuitActive(ipc);
      expect(calls, ['save:b_3', 'close:b_3']);
    });

    test(':wq is a no-op with no active buffer', () async {
      ipc.stub('editor.active', (_) async => _ok({'active': null}));
      record('editor.save');
      record('editor.close');
      await exWriteQuitActive(ipc);
      expect(calls, isEmpty);
    });

    test(':N dispatches editor.goto-line with the line', () async {
      ipc.stub('editor.goto-line', (a) async {
        calls.add('goto:${a['line']}');
        return _ok({});
      });
      await exGotoLineActive(ipc, 42);
      expect(calls, ['goto:42']);
    });
  });
}
