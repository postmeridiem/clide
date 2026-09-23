#ifndef CLIDE_LOADER_H_
#define CLIDE_LOADER_H_

// D-110: `clide --loader` — the headless process that owns the one tray icon
// shared by every clide window. Native only (no Flutter engine). Returns the
// process exit status; exits at once when another loader already runs.
int clide_loader_run();

#endif  // CLIDE_LOADER_H_
