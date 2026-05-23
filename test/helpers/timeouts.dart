/// Shared test timeouts. Flutter-free on purpose, so both `dart test`
/// (the pty / ipc suites) and `flutter test` files can import it.
library;

/// Generous timeout for waiting on real external I/O — PTY output, fs
/// watcher events, socket round-trips. A working path responds in well
/// under a second; this is pure headroom so transient scheduling latency
/// doesn't flake the gate. A genuinely broken path still fails — just
/// later. Tune here, once, rather than scattering magic seconds.
const Duration ioTimeout = Duration(seconds: 20);
