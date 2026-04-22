/// PTY subsystem — spawn child processes under a PTY via `ptyc`,
/// expose their master fd as a byte stream. Desktop IDE's pane model
/// (terminal / Claude / future tmux wrappers) rides on this.
library;

export 'env.dart' show clidePtyEnvDefaults, mergePtyEnv;
export 'session.dart' show PtySession;
