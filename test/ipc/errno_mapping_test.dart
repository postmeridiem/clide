import 'package:clide/src/ipc/errno_mapping.dart';
import 'package:clide/src/ipc/schema_v1.dart';
import 'package:test/test.dart';

void main() {
  group('errnoToIpcError', () {
    test('ENOENT → notFound with target', () {
      final err = errnoToIpcError(errno: PosixErrno.enoent, op: 'pane.spawn', target: 'claude');
      expect(err.kind, IpcErrorKind.notFound);
      expect(err.code, IpcExitCode.notFound);
      expect(err.message, contains('claude'));
      expect(err.message, contains('not found'));
    });

    test('EACCES → userError with hint', () {
      final err = errnoToIpcError(errno: PosixErrno.eacces, op: 'editor.open', target: '/etc/shadow');
      expect(err.kind, IpcErrorKind.userError);
      expect(err.code, IpcExitCode.userError);
      expect(err.message, contains('permission denied'));
      expect(err.hint, isNotNull);
    });

    test('EISDIR → userError', () {
      final err = errnoToIpcError(errno: PosixErrno.eisdir, op: 'editor.open', target: 'src/');
      expect(err.kind, IpcErrorKind.userError);
      expect(err.message, contains('is a directory'));
    });

    test('EEXIST → conflict', () {
      final err = errnoToIpcError(errno: PosixErrno.eexist, op: 'files.create', target: 'README.md');
      expect(err.kind, IpcErrorKind.conflict);
      expect(err.code, IpcExitCode.conflict);
    });

    test('EMFILE → toolError with hint', () {
      final err = errnoToIpcError(errno: PosixErrno.emfile, op: 'pane.spawn');
      expect(err.kind, IpcErrorKind.toolError);
      expect(err.message, contains('too many open files'));
      expect(err.hint, isNotNull);
    });

    test('unknown errno falls through to toolError', () {
      final err = errnoToIpcError(errno: 999, op: 'pane.spawn');
      expect(err.kind, IpcErrorKind.toolError);
      expect(err.code, IpcExitCode.toolError);
      expect(err.message, contains('errno=999'));
    });

    test('raw message overrides errno suffix in fallback', () {
      final err = errnoToIpcError(errno: 999, op: 'pane.spawn', raw: 'kernel exploded');
      expect(err.message, contains('kernel exploded'));
      expect(err.message, isNot(contains('errno=999')));
    });
  });
}
