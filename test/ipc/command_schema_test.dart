/// Tests for the typed command-schema framework (T-120 / D-74):
/// argument coercion, per-constraint validation, the argv-shape
/// normaliser, and the dispatcher-level validation hook.
library;

import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/ipc/command_schema.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/schema_v1.dart';
import 'package:test/test.dart';

void main() {
  group('ArgSpec coercion + constraints', () {
    SchemaResult run(ArgSpec spec, Object? value, {bool required = false}) {
      final schema = CommandSchema(args: {'x': spec});
      return schema.validate({'x': value});
    }

    test('string passes through; non-string rejected', () {
      expect(run(const ArgSpec(), 'hi').isOk, isTrue);
      final bad = run(const ArgSpec(), 42);
      expect(bad.isOk, isFalse);
      expect(bad.error, contains('expected a string'));
    });

    test('number coerces from a numeric string', () {
      final r = run(const ArgSpec(type: ArgType.number), '3.5');
      expect(r.isOk, isTrue);
      expect(r.values!['x'], 3.5);
    });

    test('number rejects non-numeric text', () {
      final r = run(const ArgSpec(type: ArgType.number), 'abc');
      expect(r.isOk, isFalse);
      expect(r.error, contains('expected a number'));
    });

    test('number honours min/max bounds', () {
      expect(run(const ArgSpec(type: ArgType.number, min: 0, max: 1), 0.5).isOk, isTrue);
      expect(run(const ArgSpec(type: ArgType.number, min: 0), -1).error, contains('>= 0'));
      expect(run(const ArgSpec(type: ArgType.number, max: 1), 2).error, contains('<= 1'));
    });

    test('boolean coerces from "true"/"false" strings', () {
      expect(run(const ArgSpec(type: ArgType.boolean), 'true').values!['x'], true);
      expect(run(const ArgSpec(type: ArgType.boolean), 'false').values!['x'], false);
      expect(run(const ArgSpec(type: ArgType.boolean), 'maybe').isOk, isFalse);
    });

    test('rejectLeadingDash blocks an argv-injection value', () {
      final r = run(const ArgSpec(rejectLeadingDash: true), '--upload-pack=evil');
      expect(r.isOk, isFalse);
      expect(r.error, contains('must not start with "-"'));
    });

    test('allowed enforces a closed set', () {
      final spec = ArgSpec(allowed: {'a', 'b'});
      expect(run(spec, 'a').isOk, isTrue);
      expect(run(spec, 'z').error, contains('one of'));
    });

    test('pattern must fully match', () {
      final spec = ArgSpec(pattern: RegExp(r'^[0-9]+$'));
      expect(run(spec, '123').isOk, isTrue);
      expect(run(spec, '12a').error, contains('does not match'));
    });

    test('stringList coerces a scalar + caps element count', () {
      final r = run(const ArgSpec(type: ArgType.stringList), 'solo');
      expect(r.values!['x'], ['solo']);
      final capped = run(const ArgSpec(type: ArgType.stringList, maxItems: 2), ['a', 'b', 'c']);
      expect(capped.error, contains('cap is 2'));
    });

    test('stringList rejectLeadingDash inspects every element', () {
      final r = run(const ArgSpec(type: ArgType.stringList, rejectLeadingDash: true), ['ok', '-bad']);
      expect(r.isOk, isFalse);
      expect(r.error, contains('-bad'));
    });

    test('stringList rejects a value that is neither list nor string', () {
      final r = run(const ArgSpec(type: ArgType.stringList), 42);
      expect(r.isOk, isFalse);
      expect(r.error, contains('expected a list'));
    });
  });

  group('required + unknown handling', () {
    test('missing required arg fails', () {
      final s = CommandSchema(args: {'name': const ArgSpec(required: true)});
      final r = s.validate(const {});
      expect(r.isOk, isFalse);
      expect(r.error, contains('name is required'));
    });

    test('missing optional arg is fine', () {
      final s = CommandSchema(args: {'name': const ArgSpec()});
      expect(s.validate(const {}).isOk, isTrue);
    });

    test('undeclared keys are preserved untouched', () {
      final s = CommandSchema(args: {'a': const ArgSpec()});
      final r = s.validate(const {'a': 'x', 'extra': 99});
      expect(r.isOk, isTrue);
      expect(r.values!['extra'], 99);
    });
  });

  group('normalize (argv shape → named args)', () {
    const schema = CommandSchema(
      positional: ['slot'],
      args: {'slot': ArgSpec(), 'to': ArgSpec(type: ArgType.number)},
    );

    test('positional[i] maps to the i-th declared name', () {
      final out = schema.normalize(const {
        'positional': ['sidebar'],
        'flags': {'to': '300'},
      });
      expect(out['slot'], 'sidebar');
      expect(out['to'], '300');
    });

    test('passthrough is carried over', () {
      final out = schema.normalize(const {
        'positional': ['x'],
        'passthrough': ['--', 'raw'],
      });
      expect(out['passthrough'], ['--', 'raw']);
    });

    test('direct (already-named) shape is returned unchanged', () {
      final input = {'slot': 'context', 'to': 240};
      expect(identical(schema.normalize(input), input), isTrue);
    });

    test('extra positionals beyond the declared names are dropped', () {
      final out = schema.normalize(const {
        'positional': ['a', 'b', 'c'],
      });
      expect(out['slot'], 'a');
      expect(out.containsKey('b'), isFalse);
    });
  });

  group('DaemonDispatcher schema gate', () {
    test('validates + coerces before the handler runs', () async {
      final d = DaemonDispatcher();
      Object? seen;
      d.register('demo.cmd', (req) async {
        seen = req.args['n'];
        return IpcResponse.ok(id: req.id, data: const {});
      }, schema: const CommandSchema(args: {'n': ArgSpec(type: ArgType.number)}));

      final r = await d.dispatch(IpcRequest(id: '1', cmd: 'demo.cmd', args: const {'n': '7'}));
      expect(r.ok, isTrue);
      expect(seen, 7); // coerced from the string "7"
    });

    test('rejects a violation with userError before the handler runs', () async {
      final d = DaemonDispatcher();
      var handlerRan = false;
      d.register('demo.cmd', (req) async {
        handlerRan = true;
        return IpcResponse.ok(id: req.id, data: const {});
      }, schema: const CommandSchema(args: {'ref': ArgSpec(rejectLeadingDash: true, required: true)}));

      final r = await d.dispatch(IpcRequest(id: '1', cmd: 'demo.cmd', args: const {'ref': '-rf'}));
      expect(r.ok, isFalse);
      expect(r.error!.kind, IpcErrorKind.userError);
      expect(handlerRan, isFalse);
    });

    test('a command with no schema dispatches unvalidated', () async {
      final d = DaemonDispatcher();
      d.register('demo.bare', (req) async {
        return IpcResponse.ok(id: req.id, data: {'echo': req.args['anything']});
      });
      final r = await d.dispatch(IpcRequest(id: '1', cmd: 'demo.bare', args: const {'anything': '-not-checked'}));
      expect(r.ok, isTrue);
      expect(r.data['echo'], '-not-checked');
    });

    test('re-registering a command without a schema clears its old schema', () async {
      final d = DaemonDispatcher();
      handler(IpcRequest req) async => IpcResponse.ok(id: req.id, data: const {});
      d.register('demo.cmd', handler, schema: const CommandSchema(args: {'r': ArgSpec(required: true)}));
      d.register('demo.cmd', handler); // no schema this time
      final r = await d.dispatch(IpcRequest(id: '1', cmd: 'demo.cmd', args: const {}));
      expect(r.ok, isTrue); // required check no longer applies
    });
  });
}
