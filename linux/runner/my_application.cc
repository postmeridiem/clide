#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif
#ifdef HAS_WAYLAND_CLIENT
#include "protocols/server-decoration-client-protocol.h"
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// D-057: KDE server-decoration protocol — request no decorations.
#ifdef HAS_WAYLAND_CLIENT
static struct org_kde_kwin_server_decoration_manager* kde_deco_manager = nullptr;

static void registry_handler(void* data, struct wl_registry* registry,
                             uint32_t id, const char* interface,
                             uint32_t version) {
  if (g_strcmp0(interface,
               org_kde_kwin_server_decoration_manager_interface.name) == 0) {
    kde_deco_manager = (struct org_kde_kwin_server_decoration_manager*)
        wl_registry_bind(registry, id,
                         &org_kde_kwin_server_decoration_manager_interface, 1);
  }
}

static void registry_remover(void* data, struct wl_registry* registry,
                             uint32_t id) {}

static const struct wl_registry_listener registry_listener = {
    registry_handler, registry_remover};

static void kde_deco_default_mode(void* data,
    struct org_kde_kwin_server_decoration_manager* mgr, uint32_t mode) {}

static const struct org_kde_kwin_server_decoration_manager_listener
    kde_deco_manager_listener = {kde_deco_default_mode};

static void request_no_server_decorations(GtkWindow* window) {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  if (!GDK_IS_WAYLAND_DISPLAY(display)) return;

  struct wl_display* wl_dpy =
      gdk_wayland_display_get_wl_display(display);
  struct wl_registry* registry = wl_display_get_registry(wl_dpy);
  wl_registry_add_listener(registry, &registry_listener, nullptr);
  wl_display_roundtrip(wl_dpy);

  if (kde_deco_manager == nullptr) {
    wl_registry_destroy(registry);
    return;
  }

  org_kde_kwin_server_decoration_manager_add_listener(
      kde_deco_manager, &kde_deco_manager_listener, nullptr);
  wl_display_roundtrip(wl_dpy);

  GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_win == nullptr) {
    wl_registry_destroy(registry);
    return;
  }

  struct wl_surface* surface = gdk_wayland_window_get_wl_surface(gdk_win);
  if (surface == nullptr) {
    wl_registry_destroy(registry);
    return;
  }

  struct org_kde_kwin_server_decoration* deco =
      org_kde_kwin_server_decoration_manager_create(kde_deco_manager, surface);
  if (deco != nullptr) {
    // Mode 0 = None (no decorations at all)
    org_kde_kwin_server_decoration_request_mode(deco, 0);
    wl_display_roundtrip(wl_dpy);
  }

  wl_registry_destroy(registry);
}
#endif

static void on_window_realize(GtkWidget* widget, gpointer data) {
  GdkWindow* gdk_win = gtk_widget_get_window(widget);
  if (gdk_win != nullptr) {
    gdk_window_set_decorations(gdk_win, (GdkWMDecoration)0);
  }
#ifdef HAS_WAYLAND_CLIENT
  request_no_server_decorations(GTK_WINDOW(widget));
#endif
}

static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // D-057: frameless custom chrome.
  gtk_window_set_decorated(window, FALSE);
  gtk_window_set_title(window, "clide");
  g_signal_connect(window, "realize", G_CALLBACK(on_window_realize), nullptr);

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(GError) icon_error = nullptr;
  GdkPixbuf* icon = gdk_pixbuf_new_from_file(
      "data/flutter_assets/assets/logo/clide-logo-256.png", &icon_error);
  if (icon != nullptr) {
    gtk_window_set_icon(window, icon);
    g_object_unref(icon);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // D-057: method channel for window controls.
  FlEngine* engine = fl_view_get_engine(view);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(engine), "clide/window",
      FL_METHOD_CODEC(codec));
  g_object_set_data(G_OBJECT(window), "clide_method_channel", channel);
  fl_method_channel_set_method_call_handler(
      channel,
      [](FlMethodChannel* channel, FlMethodCall* method_call,
         gpointer user_data) {
        GtkWindow* w = GTK_WINDOW(user_data);
        const gchar* method = fl_method_call_get_name(method_call);
        g_autoptr(FlMethodResponse) response = nullptr;

        if (g_strcmp0(method, "startDrag") == 0) {
          FlValue* args = fl_method_call_get_args(method_call);
          int x = 0, y = 0;
          if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
            FlValue* vx = fl_value_lookup_string(args, "x");
            FlValue* vy = fl_value_lookup_string(args, "y");
            if (vx) x = (int)fl_value_get_int(vx);
            if (vy) y = (int)fl_value_get_int(vy);
          }
          gtk_window_begin_move_drag(w, 1, x, y, GDK_CURRENT_TIME);
          response = FL_METHOD_RESPONSE(
              fl_method_success_response_new(fl_value_new_null()));
        } else if (g_strcmp0(method, "startResize") == 0) {
          FlValue* args = fl_method_call_get_args(method_call);
          int edge = 7, x = 0, y = 0;
          if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
            FlValue* ve = fl_value_lookup_string(args, "edge");
            FlValue* vx = fl_value_lookup_string(args, "x");
            FlValue* vy = fl_value_lookup_string(args, "y");
            if (ve) edge = (int)fl_value_get_int(ve);
            if (vx) x = (int)fl_value_get_int(vx);
            if (vy) y = (int)fl_value_get_int(vy);
          }
          static const GdkWindowEdge edges[] = {
            GDK_WINDOW_EDGE_NORTH_WEST, GDK_WINDOW_EDGE_NORTH,
            GDK_WINDOW_EDGE_NORTH_EAST, GDK_WINDOW_EDGE_WEST,
            GDK_WINDOW_EDGE_EAST, GDK_WINDOW_EDGE_SOUTH_WEST,
            GDK_WINDOW_EDGE_SOUTH, GDK_WINDOW_EDGE_SOUTH_EAST,
          };
          if (edge >= 0 && edge < 8) {
            gtk_window_begin_resize_drag(w, edges[edge], 1, x, y,
                                         GDK_CURRENT_TIME);
          }
          response = FL_METHOD_RESPONSE(
              fl_method_success_response_new(fl_value_new_null()));
        } else if (g_strcmp0(method, "minimize") == 0) {
          gtk_window_iconify(w);
          response = FL_METHOD_RESPONSE(
              fl_method_success_response_new(fl_value_new_null()));
        } else if (g_strcmp0(method, "maximize") == 0) {
          if (gtk_window_is_maximized(w)) {
            gtk_window_unmaximize(w);
          } else {
            gtk_window_maximize(w);
          }
          response = FL_METHOD_RESPONSE(
              fl_method_success_response_new(fl_value_new_null()));
        } else if (g_strcmp0(method, "close") == 0) {
          gtk_window_close(w);
          response = FL_METHOD_RESPONSE(
              fl_method_success_response_new(fl_value_new_null()));
        } else if (g_strcmp0(method, "isMaximized") == 0) {
          response = FL_METHOD_RESPONSE(fl_method_success_response_new(
              fl_value_new_bool(gtk_window_is_maximized(w))));
        } else {
          response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
        }

        fl_method_call_respond(method_call, response, nullptr);
      },
      window, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;
  return TRUE;
}

static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
