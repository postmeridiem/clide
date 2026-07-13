/// Web stub (T-438 web fence, D-100): no FFI fd-inheritance probe on web.
library;

/// Mirrors [fd_check_io.dart]; never exists on web, so the probe is skipped.
const fdCheckHelperPath = '/tmp/checkfd';

Future<String> fdInheritanceCheck() async => 'skipped (no FFI on web)';
