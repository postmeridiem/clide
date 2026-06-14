/// PTY subsystem — spawn child processes under a PTY and expose their
/// output as a byte stream. POSIX uses posix_openpt() + posix_spawn();
/// Windows uses ConPTY. Desktop IDE's pane model (terminal / Claude /
/// future tmux wrappers) rides on this.
library;

export 'env.dart' show clidePtyEnvDefaults, mergePtyEnv;
export 'native_pty.dart' show NativePty;
export 'pty_session.dart' show PtySession, startPtySession;
export 'windows_pty.dart' show WindowsPty;
