#ifndef CLIDE_APP_H_
#define CLIDE_APP_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(ClideApp, clide_app, CLIDE, APP, GtkApplication)

ClideApp* clide_app_new();

#endif  // CLIDE_APP_H_
