#include <string.h>

#include "clide_app.h"
#include "clide_loader.h"

int main(int argc, char** argv) {
  // D-110: `clide --loader` is the headless tray loader — no window, no
  // Flutter engine. Windows start it themselves when none is running.
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--loader") == 0) return clide_loader_run();
  }
  g_autoptr(ClideApp) app = clide_app_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
