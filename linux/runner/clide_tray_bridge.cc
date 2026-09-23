// D-110: window-side tray bridge. See clide_tray_bridge.h.
#include "clide_tray_bridge.h"

#include <gio/gio.h>
#include <unistd.h>

#include "clide_tray_protocol.h"

namespace {

// A loader that can't start (no session bus, a crash loop) must not be
// respawned on every name-vanished notification.
constexpr gint64 kRespawnBackoffUs = 5 * G_USEC_PER_SEC;

struct Bridge {
  GtkWindow* window = nullptr;
  FlMethodChannel* channel = nullptr;
  GDBusConnection* conn = nullptr;
  // Off until Dart pushes the setting: before that, close quits as it always
  // did. The Dart default (on) arrives within the first frames.
  gboolean close_to_tray = FALSE;
  gboolean tray_available = FALSE;
  gboolean loader_present = FALSE;
  gboolean quitting = FALSE;
  gboolean disabled = FALSE;
  gchar* workspace = nullptr;
  GHashTable* labels = nullptr;
  gint64 last_spawn_us = 0;
};

Bridge B;

gboolean window_visible() { return gtk_widget_get_visible(GTK_WIDGET(B.window)); }

void tell_dart_availability() {
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "available", fl_value_new_bool(B.tray_available));
  fl_method_channel_invoke_method(B.channel, "availability", args, nullptr, nullptr, nullptr);
}

void set_tray_available(gboolean available) {
  if (available == B.tray_available) return;
  B.tray_available = available;
  tell_dart_availability();
}

// -- talking to the loader ----------------------------------------------------

void loader_call(const char* method, GVariant* params) {
  if (!B.loader_present) {
    if (params != nullptr) g_variant_unref(g_variant_ref_sink(params));
    return;
  }
  g_dbus_connection_call(B.conn, CLIDE_LOADER_BUS_NAME, CLIDE_LOADER_OBJECT_PATH, CLIDE_LOADER_INTERFACE, method,
                         params, nullptr, G_DBUS_CALL_FLAGS_NONE, -1, nullptr, nullptr, nullptr);
}

void loader_update() { loader_call("Update", g_variant_new("(sb)", B.workspace ? B.workspace : "", window_visible())); }

void loader_set_labels() {
  if (g_hash_table_size(B.labels) == 0) return;
  GVariantBuilder b;
  g_variant_builder_init(&b, G_VARIANT_TYPE("a{ss}"));
  GHashTableIter it;
  gpointer k, v;
  g_hash_table_iter_init(&it, B.labels);
  while (g_hash_table_iter_next(&it, &k, &v)) g_variant_builder_add(&b, "{ss}", (const char*)k, (const char*)v);
  loader_call("SetLabels", g_variant_new("(@a{ss})", g_variant_builder_end(&b)));
}

void on_register_reply(GObject* src, GAsyncResult* res, gpointer) {
  g_autoptr(GVariant) reply = g_dbus_connection_call_finish(G_DBUS_CONNECTION(src), res, nullptr);
  if (reply == nullptr) return;
  gboolean available = FALSE;
  g_variant_get(reply, "(b)", &available);
  set_tray_available(available);
}

void spawn_loader() {
  const gint64 now = g_get_monotonic_time();
  if (B.last_spawn_us != 0 && now - B.last_spawn_us < kRespawnBackoffUs) return;
  B.last_spawn_us = now;
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  if (exe == nullptr) return;
  gchar* argv[] = {exe, (gchar*)"--loader", nullptr};
  // Own session, output discarded: the loader outlives this window (and any
  // `flutter run` pipe that would SIGPIPE it once gone). g_spawn_async without
  // DO_NOT_REAP double-forks, so nothing is left for us to reap.
  g_autoptr(GError) error = nullptr;
  if (!g_spawn_async(nullptr, argv, nullptr,
                     (GSpawnFlags)(G_SPAWN_STDOUT_TO_DEV_NULL | G_SPAWN_STDERR_TO_DEV_NULL),
                     [](gpointer) { setsid(); }, nullptr, nullptr, &error)) {
    g_warning("clide: could not start the tray loader: %s", error->message);
  }
}

void on_loader_appeared(GDBusConnection*, const char*, const char*, gpointer) {
  B.loader_present = TRUE;
  g_dbus_connection_call(B.conn, CLIDE_LOADER_BUS_NAME, CLIDE_LOADER_OBJECT_PATH, CLIDE_LOADER_INTERFACE, "Register",
                         g_variant_new("(sb)", B.workspace ? B.workspace : "", window_visible()),
                         G_VARIANT_TYPE("(b)"), G_DBUS_CALL_FLAGS_NONE, -1, nullptr, on_register_reply, nullptr);
  loader_set_labels();
}

void on_loader_vanished(GDBusConnection*, const char*, gpointer) {
  B.loader_present = FALSE;
  set_tray_available(FALSE);
  if (!B.quitting) spawn_loader();
}

void on_loader_signal(GDBusConnection*, const char*, const char*, const char*, const char* signal, GVariant* params,
                      gpointer) {
  if (g_strcmp0(signal, "TrayAvailabilityChanged") != 0) return;
  gboolean available = FALSE;
  g_variant_get(params, "(b)", &available);
  set_tray_available(available);
}

// -- window operations --------------------------------------------------------

void show_window() {
  gtk_widget_show(GTK_WIDGET(B.window));
  gtk_window_present(B.window);
  loader_update();
}

// Refused unless something can bring the window back.
gboolean hide_window() {
  if (!B.tray_available) return FALSE;
  gtk_widget_hide(GTK_WIDGET(B.window));
  loader_update();
  return TRUE;
}

gboolean quit_idle(gpointer) {
  GApplication* app = g_application_get_default();
  if (app != nullptr) g_application_quit(app);
  return G_SOURCE_REMOVE;
}

// Deferred a tick so a Dart caller gets its reply before the process goes.
void quit_process() {
  B.quitting = TRUE;
  g_idle_add(quit_idle, nullptr);
}

void quit_all() {
  if (B.loader_present) {
    loader_call("QuitAll", nullptr);  // the loader calls our Quit too
  } else {
    quit_process();
  }
}

gboolean on_delete_event(GtkWidget*, GdkEvent*, gpointer) {
  if (!B.quitting && B.close_to_tray && hide_window()) return TRUE;
  return FALSE;  // default: destroy the window, which ends the app
}

// -- the Window interface the loader drives -----------------------------------

void on_window_call(GDBusConnection*, const char*, const char*, const char*, const char* method, GVariant*,
                    GDBusMethodInvocation* inv, gpointer) {
  if (g_strcmp0(method, "Show") == 0) {
    show_window();
  } else if (g_strcmp0(method, "Hide") == 0) {
    hide_window();
  } else if (g_strcmp0(method, "Quit") == 0) {
    quit_process();
  }
  g_dbus_method_invocation_return_value(inv, nullptr);
}

// -- the clide/tray channel ---------------------------------------------------

FlMethodResponse* ok(FlValue* v) { return FL_METHOD_RESPONSE(fl_method_success_response_new(v)); }

void on_channel_call(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "isAvailable") == 0) {
    response = ok(fl_value_new_bool(B.tray_available));
  } else if (g_strcmp0(method, "setCloseToTray") == 0) {
    B.close_to_tray = args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_BOOL && fl_value_get_bool(args);
    response = ok(fl_value_new_bool(TRUE));
  } else if (g_strcmp0(method, "setWorkspace") == 0) {
    g_free(B.workspace);
    B.workspace = (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_STRING)
                      ? g_strdup(fl_value_get_string(args))
                      : nullptr;
    loader_update();
    response = ok(fl_value_new_bool(TRUE));
  } else if (g_strcmp0(method, "setLabels") == 0) {
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      for (size_t i = 0; i < fl_value_get_length(args); i++) {
        FlValue* k = fl_value_get_map_key(args, i);
        FlValue* v = fl_value_get_map_value(args, i);
        if (fl_value_get_type(k) == FL_VALUE_TYPE_STRING && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
          g_hash_table_replace(B.labels, g_strdup(fl_value_get_string(k)), g_strdup(fl_value_get_string(v)));
        }
      }
    }
    loader_set_labels();
    response = ok(fl_value_new_bool(TRUE));
  } else if (g_strcmp0(method, "show") == 0) {
    show_window();
    response = ok(fl_value_new_bool(TRUE));
  } else if (g_strcmp0(method, "hide") == 0) {
    response = ok(fl_value_new_bool(hide_window()));
  } else if (g_strcmp0(method, "quit") == 0) {
    quit_process();
    response = ok(fl_value_new_bool(TRUE));
  } else if (g_strcmp0(method, "quitAll") == 0) {
    quit_all();
    response = ok(fl_value_new_bool(TRUE));
  } else if (g_strcmp0(method, "pulse") == 0) {
    loader_call("Pulse", nullptr);
    response = ok(fl_value_new_bool(B.loader_present));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, response, nullptr);
}

}  // namespace

void clide_tray_bridge_attach(GtkWindow* window, FlBinaryMessenger* messenger) {
  B.window = window;
  B.labels = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
  B.disabled = g_strcmp0(g_getenv("CLIDE_NO_TRAY"), "1") == 0;

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  B.channel = fl_method_channel_new(messenger, "clide/tray", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(B.channel, on_channel_call, nullptr, nullptr);
  g_signal_connect(window, "delete-event", G_CALLBACK(on_delete_event), nullptr);

  if (B.disabled) return;
  g_autoptr(GError) error = nullptr;
  B.conn = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (B.conn == nullptr) {
    g_warning("clide: no session bus, tray disabled: %s", error->message);
    return;
  }

  g_autoptr(GDBusNodeInfo) node = g_dbus_node_info_new_for_xml(kClideWindowIntrospection, nullptr);
  const GDBusInterfaceVTable vtable = {on_window_call, nullptr, nullptr, {nullptr}};
  g_dbus_connection_register_object(B.conn, CLIDE_WINDOW_OBJECT_PATH, node->interfaces[0], &vtable, nullptr, nullptr,
                                    nullptr);
  g_dbus_connection_signal_subscribe(B.conn, CLIDE_LOADER_BUS_NAME, CLIDE_LOADER_INTERFACE, nullptr,
                                     CLIDE_LOADER_OBJECT_PATH, nullptr, G_DBUS_SIGNAL_FLAGS_NONE, on_loader_signal,
                                     nullptr, nullptr);
  // Fires `vanished` at once when no loader runs — which starts one.
  g_bus_watch_name_on_connection(B.conn, CLIDE_LOADER_BUS_NAME, G_BUS_NAME_WATCHER_FLAGS_NONE, on_loader_appeared,
                                 on_loader_vanished, nullptr, nullptr);
}
