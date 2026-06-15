/// Resolve the `native/<os>-<arch>/` directory name via FFI ABI introspection
/// (T-438 web fence, D-100). Desktop-only; the web build uses
/// [native_abi_stub.dart], so `dart:ffi` (here, only `Abi`) stays out of the
/// wasm graph.
library;

import 'dart:ffi' show Abi;
import 'dart:io' show Platform;

/// The `<os>-<arch>` dir name for the current process (e.g. `linux-x64`,
/// `macos-arm64`) — used to find a dev-tree `clide` binary when running
/// un-installed. [abi] is an injection seam for tests; production passes none.
String currentNativeDirName({Abi? abi}) {
  switch (abi ?? Abi.current()) {
    case Abi.macosArm64:
      return 'macos-arm64';
    case Abi.macosX64:
      return 'macos-x64';
    case Abi.linuxArm64:
      return 'linux-arm64';
    case Abi.linuxX64:
      return 'linux-x64';
    default:
      // Windows / other — clide is desktop linux/macOS today; fall back to a
      // best-effort name so the probe simply misses rather than throwing.
      return Platform.isMacOS ? 'macos-x64' : 'linux-x64';
  }
}
