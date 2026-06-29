/// The `d2` drawing-card template (T-494 / D-91 / D-103).
///
/// A d2 diagram is just an SVG card with a compile step in front: the doc's
/// `source` (d2 diagram text) is compiled to SVG, then painted by the SAME
/// renderer the `svg` card uses (T-320). The compile shells out to the `d2`
/// binary — the supporter-tool pattern (peer of pql/git, D-3/D-5), resolved via
/// the D-104 path layer (T-495). No second core language, no vendored Go.
///
/// Honest failures (D-103): a missing source, an unresolved `d2`, or a compile
/// error each return a [DrawErr] with a user-facing message + hint, which the
/// command layer turns into an IpcError userError — never a throw.
///
/// Flutter-free: pure Dart (dart:io), runs under `dart test`. The process spawn
/// is injectable ([D2Compiler]) so the handler is tested without a real binary.
library;

import 'dart:convert';
import 'dart:io';

import '../env/supporter_binaries.dart';
import 'draw_dispatch.dart';

/// Compiles d2 [source] to an SVG [DrawResult]. Injected into
/// [d2TemplateHandler] so it is testable; the default is [d2CompileViaBinary].
typedef D2Compiler = Future<DrawResult> Function(String source);

/// Handler for `template: "d2"` — reads the doc's `source` field (the diagram
/// text) and compiles it. Register this in the [DrawingRegistry].
DrawingTemplateHandler d2TemplateHandler({D2Compiler compile = d2CompileViaBinary}) {
  return (doc) async {
    final source = doc.fields['source'];
    if (source is! String || source.trim().isEmpty) {
      return const DrawErr('the d2 template needs a non-empty "source" field (the d2 diagram text)');
    }
    return compile(source);
  };
}

/// One run of the d2 binary: its exit code, stdout (SVG) and stderr.
typedef D2RunResult = ({int code, String out, String err});

/// Runs the d2 [exe] over [source]. Injected so [d2CompileViaBinary] is tested
/// without a real binary; the default is [_spawnD2].
typedef D2Run = Future<D2RunResult> Function(String exe, String source);

/// Resolve the `d2` binary (D-104) and compile [source] through it. Failure keys
/// off the exit code — d2 logs `success:` to stderr on a clean compile, so a
/// non-empty stderr is not itself an error. [resolveD2] and [run] are injectable
/// for testing; the defaults use [activeSupporterBinaries] and a real spawn.
Future<DrawResult> d2CompileViaBinary(String source, {String? Function()? resolveD2, D2Run run = _spawnD2}) async {
  final d2 = (resolveD2 ?? _defaultResolveD2)();
  if (d2 == null) {
    return const DrawErr('d2 not found — install it from https://d2lang.com, or set its path in Settings → Tools');
  }
  final D2RunResult r;
  try {
    r = await run(d2, source);
  } catch (e) {
    return DrawErr('could not run d2 ($d2): $e');
  }
  if (r.code != 0) {
    return DrawErr('d2 compile failed: ${r.err.trim().isEmpty ? 'exit ${r.code}' : r.err.trim()}');
  }
  if (r.out.trim().isEmpty) return const DrawErr('d2 produced no SVG');
  return DrawOk(r.out);
}

String? _defaultResolveD2() => (activeSupporterBinaries ?? SupporterBinaries()).resolve('d2');

/// `d2 - -` — read source on stdin, write SVG to stdout. Drains stdout/stderr
/// concurrently with the stdin write to avoid a pipe deadlock on a big diagram.
Future<D2RunResult> _spawnD2(String exe, String source) async {
  final proc = await Process.start(exe, const ['-', '-']);
  final outF = proc.stdout.transform(utf8.decoder).join();
  final errF = proc.stderr.transform(utf8.decoder).join();
  proc.stdin.write(source);
  await proc.stdin.close();
  final code = await proc.exitCode;
  return (code: code, out: await outF, err: await errF);
}
