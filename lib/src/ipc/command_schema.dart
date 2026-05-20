/// Typed argument schema for IPC commands (T-120, per D-74).
///
/// A [CommandSchema] declares the arguments a command accepts — their
/// types, whether they're required, and per-argument constraints
/// (charset/pattern, leading-dash rejection, numeric range, list
/// caps). Schemas are registered alongside their handlers on the
/// `DaemonDispatcher`; the dispatcher normalises + validates
/// `req.args` against the registered schema *before* invoking the
/// handler, so a command can never see malformed input and no handler
/// has to hand-roll its own argument checks.
///
/// Two call shapes reach a command (see T-119): the direct shape
/// (`{branch: "main"}`, from the in-process `DaemonClient` / UI) and
/// the argv-translator shape (`{positional: [...], flags: {...}}`,
/// from the C `clide` client). [CommandSchema.normalize] folds the
/// argv shape into named arguments using the schema's positional
/// ordering, so handlers only ever read flat named keys.
///
/// Flutter-free by construction — lives under `lib/src/ipc/` and
/// imports nothing from the kernel. The constraint vocabulary is
/// hand-rolled per the prefer-zero-deps guardrail.
library;

import 'envelope.dart';
import 'schema_v1.dart';

/// Coarse type of an argument value after coercion.
enum ArgType { string, number, boolean, stringList }

/// Constraints on a single argument.
class ArgSpec {
  const ArgSpec({
    this.type = ArgType.string,
    this.required = false,
    this.pattern,
    this.rejectLeadingDash = false,
    this.min,
    this.max,
    this.maxItems,
    this.allowed,
  });

  final ArgType type;
  final bool required;

  /// String only — the value must fully match this pattern.
  final RegExp? pattern;

  /// String / stringList — reject any value (or element) starting with
  /// `-`. This is the argv-injection guard T-104 introduced for git
  /// refs; the schema makes it declarative.
  final bool rejectLeadingDash;

  /// Number only — inclusive bounds.
  final num? min;
  final num? max;

  /// stringList only — maximum element count.
  final int? maxItems;

  /// String only — closed set of accepted values.
  final Set<String>? allowed;

  /// Coerce [raw] to this spec's [type]. Returns the typed value, or a
  /// [_CoerceError] when the raw value can't be represented as the
  /// declared type. Flag values arrive as strings from the argv
  /// translator, so numeric/boolean args parse from text here.
  Object? _coerce(Object? raw, void Function(String) fail) {
    switch (type) {
      case ArgType.string:
        if (raw is String) return raw;
        fail('expected a string');
        return null;
      case ArgType.number:
        if (raw is num) return raw;
        if (raw is String) {
          final n = num.tryParse(raw);
          if (n != null) return n;
        }
        fail('expected a number');
        return null;
      case ArgType.boolean:
        if (raw is bool) return raw;
        if (raw == 'true') return true;
        if (raw == 'false') return false;
        fail('expected a boolean');
        return null;
      case ArgType.stringList:
        if (raw is List) {
          return raw.map((e) => '$e').toList();
        }
        if (raw is String) return [raw];
        fail('expected a list');
        return null;
    }
  }

  /// Apply value constraints to an already-coerced [value]. Returns
  /// null when valid, else a human-readable reason.
  String? _check(Object? value) {
    switch (type) {
      case ArgType.string:
        final s = value as String;
        if (rejectLeadingDash && s.startsWith('-')) {
          return 'must not start with "-"';
        }
        if (allowed != null && !allowed!.contains(s)) {
          return 'must be one of ${allowed!.join(", ")}';
        }
        if (pattern != null && !pattern!.hasMatch(s)) {
          return 'does not match ${pattern!.pattern}';
        }
        return null;
      case ArgType.number:
        final n = value as num;
        if (min != null && n < min!) return 'must be >= $min';
        if (max != null && n > max!) return 'must be <= $max';
        return null;
      case ArgType.boolean:
        return null;
      case ArgType.stringList:
        final list = (value as List).cast<String>();
        if (maxItems != null && list.length > maxItems!) {
          return 'has ${list.length} items; cap is $maxItems';
        }
        if (rejectLeadingDash) {
          for (final e in list) {
            if (e.startsWith('-')) return 'element "$e" must not start with "-"';
          }
        }
        return null;
    }
  }
}

/// The argument contract for one command.
class CommandSchema {
  const CommandSchema({this.positional = const [], this.args = const {}});

  /// Names for positional argv tokens, in order. `positional[i]` in the
  /// argv-translator shape maps to the argument named `positional[i]`.
  final List<String> positional;

  /// Argument name → spec. Includes the positional names.
  final Map<String, ArgSpec> args;

  /// Reserved keys the argv translator emits — never argument names.
  static const _argvKeys = {'positional', 'flags', 'passthrough'};

  /// Fold the argv-translator shape (`{positional, flags}`) into flat
  /// named arguments using [positional] ordering. The direct call
  /// shape (already flat named keys) is returned unchanged.
  Map<String, Object?> normalize(Map<String, Object?> raw) {
    final looksLikeArgv = raw.keys.any(_argvKeys.contains);
    if (!looksLikeArgv) return raw;
    final out = <String, Object?>{};
    final pos = raw['positional'];
    if (pos is List) {
      for (var i = 0; i < pos.length && i < positional.length; i++) {
        out[positional[i]] = pos[i];
      }
    }
    final flags = raw['flags'];
    if (flags is Map) {
      for (final e in flags.entries) {
        out['${e.key}'] = e.value;
      }
    }
    if (raw.containsKey('passthrough')) out['passthrough'] = raw['passthrough'];
    return out;
  }

  /// Validate [normalized] (post-[normalize]) against every declared
  /// arg. Returns a [SchemaResult] carrying either the coerced argument
  /// map (declared args replaced with their typed values; undeclared
  /// keys preserved untouched) or the first violation message.
  SchemaResult validate(Map<String, Object?> normalized) {
    final out = Map<String, Object?>.from(normalized);
    for (final entry in args.entries) {
      final name = entry.key;
      final spec = entry.value;
      final present = normalized.containsKey(name) && normalized[name] != null;
      if (!present) {
        if (spec.required) return SchemaResult.err('$name is required');
        continue;
      }
      String? coerceFailure;
      final coerced = spec._coerce(normalized[name], (m) => coerceFailure = m);
      if (coerceFailure != null) return SchemaResult.err('$name: $coerceFailure');
      final reason = spec._check(coerced);
      if (reason != null) return SchemaResult.err('$name $reason');
      out[name] = coerced;
    }
    return SchemaResult.ok(out);
  }
}

/// Outcome of [CommandSchema.validate].
class SchemaResult {
  const SchemaResult.ok(this.values) : error = null;
  const SchemaResult.err(this.error) : values = null;

  /// Coerced argument map on success; null on failure.
  final Map<String, Object?>? values;

  /// Violation message on failure; null on success.
  final String? error;

  bool get isOk => error == null;
}

/// Build the standard `userError` response for a schema violation.
IpcResponse schemaError(String id, String message) => IpcResponse.err(
      id: id,
      error: IpcError(
        code: IpcExitCode.userError,
        kind: IpcErrorKind.userError,
        message: message,
      ),
    );
