/// Web/non-FFI stub for the Windows resource sampler (T-438 web fence, D-100).
///
/// [watchdog.dart] selects this when `dart.library.ffi` is absent, keeping the
/// `kernel32`/`psapi` FFI bindings out of the wasm graph. The watchdog isolate
/// never spawns on web, and `forPlatform()` never returns the Windows sampler
/// there — this exists only to satisfy the import. Returns an all-unavailable
/// sample (every field `-1`) if ever called.
library;

import 'watchdog.dart';

class WindowsResourceSampler implements ResourceSampler {
  @override
  ResourceSample sample() => const ResourceSample();
}
