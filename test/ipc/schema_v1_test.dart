import 'package:clide/clide.dart';
import 'package:test/test.dart';

void main() {
  group('schema_v1', () {
    test('schema version is 1', () {
      expect(ipcSchemaVersion, 1);
    });

    test('exit codes match ADR 0006', () {
      expect(IpcExitCode.ok, 0);
      expect(IpcExitCode.userError, 1);
      expect(IpcExitCode.toolError, 2);
      expect(IpcExitCode.notFound, 3);
      expect(IpcExitCode.conflict, 4);
    });

    test('error kinds are unique strings', () {
      final kinds = <String>{
        IpcErrorKind.userError,
        IpcErrorKind.toolError,
        IpcErrorKind.notFound,
        IpcErrorKind.conflict,
      };
      expect(kinds.length, 4);
    });
  });
}
