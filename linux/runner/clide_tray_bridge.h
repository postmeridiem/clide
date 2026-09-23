#ifndef CLIDE_TRAY_BRIDGE_H_
#define CLIDE_TRAY_BRIDGE_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

// D-110: the window process's half of the tray. Serves the `clide/tray`
// channel, turns the window's close into a hide while a tray can bring it
// back, exports the Window interface the loader drives, and finds (or
// starts) the loader. One window per process, so the state is process-wide.
//
// CLIDE_NO_TRAY=1 in the environment leaves the loader alone — the window then
// behaves as before the tray existed (close quits). For headless test runs.
void clide_tray_bridge_attach(GtkWindow* window, FlBinaryMessenger* messenger);

#endif  // CLIDE_TRAY_BRIDGE_H_
