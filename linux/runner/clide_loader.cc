// D-110: the headless tray loader (`clide --loader`).
//
// One loader per user session owns the single tray icon for every clide
// window process. Windows find it on the session bus and register (starting
// one detached if none is running); the loader lists them in the tray menu and
// drives them through the small Window interface each exports (Show / Hide /
// Quit). It never holds sessions — those stay in the window processes.
//
// The icon is a StatusNotifierItem with a minimal DBusMenu, both implemented
// directly over GDBus: no libappindicator (deprecated) or Ayatana fork (not
// reliably installed). Hosts: KDE natively, GNOME via the AppIndicator
// extension, XFCE via its SNI plugin.
#include "clide_loader.h"

#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gio/gio.h>
#include <glib-unix.h>
#include <math.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>

#include <initializer_list>

#include "clide_tray_protocol.h"

namespace {

constexpr char kWatcherName[] = "org.kde.StatusNotifierWatcher";
constexpr char kWatcherPath[] = "/StatusNotifierWatcher";
constexpr char kItemPath[] = "/StatusNotifierItem";
constexpr char kMenuPath[] = "/MenuBar";

// Menu item ids. Windows take 1..kFirstFixedId-1, in registration order.
constexpr gint32 kFirstFixedId = 1000;
constexpr gint32 kShowAllId = 1000;
constexpr gint32 kHideAllId = 1001;
constexpr gint32 kQuitAllId = 1002;
constexpr gint32 kSeparatorAId = 2000;
constexpr gint32 kSeparatorBId = 2001;

// How long the loader lingers with no windows: long enough for a window that
// is restarting (or a T-47 relaunch) to register again, short enough that no
// orphan outlives the last window for long.
constexpr guint kIdleExitSeconds = 3;
// A loader started by a window that died before registering must not linger.
constexpr guint kStartupExitSeconds = 20;

struct LoaderWindow {
  gint32 id;
  gchar* sender;  // the window's unique bus name
  gchar* workspace;
  gboolean visible;
  guint vanish_watch;
};

struct Loader {
  GMainLoop* loop = nullptr;
  GDBusConnection* conn = nullptr;
  GPtrArray* windows = nullptr;  // LoaderWindow*
  gint32 next_window_id = 1;
  GHashTable* labels = nullptr;  // label key -> localized text
  guint32 menu_revision = 1;
  gboolean watcher_present = FALSE;
  gboolean host_registered = FALSE;
  gboolean tray_available = FALSE;
  gchar* item_bus_name = nullptr;
  guint watcher_watch = 0;
  guint exit_source = 0;
  gchar* exe_dir = nullptr;
  GVariant* icon_pixmaps = nullptr;  // a(iiay), owned — fallback for pixmap-only hosts
  gchar* icon_theme_dir = nullptr;   // runtime theme holding the mark + spin frames
  const char* icon_name = "";        // current IconName ("" = pixmap only)
  gint spin_frame = 0;
  guint spin_source = 0;
};

Loader L;

// -- small helpers ------------------------------------------------------------

const char* label(const char* key, const char* fallback) {
  const char* v = L.labels ? (const char*)g_hash_table_lookup(L.labels, key) : nullptr;
  return (v != nullptr && *v != '\0') ? v : fallback;
}

void window_free(gpointer p) {
  LoaderWindow* w = (LoaderWindow*)p;
  if (w->vanish_watch != 0) g_bus_unwatch_name(w->vanish_watch);
  g_free(w->sender);
  g_free(w->workspace);
  g_free(w);
}

LoaderWindow* window_by_sender(const char* sender) {
  for (guint i = 0; i < L.windows->len; i++) {
    LoaderWindow* w = (LoaderWindow*)g_ptr_array_index(L.windows, i);
    if (g_strcmp0(w->sender, sender) == 0) return w;
  }
  return nullptr;
}

LoaderWindow* window_by_id(gint32 id) {
  for (guint i = 0; i < L.windows->len; i++) {
    LoaderWindow* w = (LoaderWindow*)g_ptr_array_index(L.windows, i);
    if (w->id == id) return w;
  }
  return nullptr;
}

void call_window(LoaderWindow* w, const char* method) {
  g_dbus_connection_call(L.conn, w->sender, CLIDE_WINDOW_OBJECT_PATH, CLIDE_WINDOW_INTERFACE, method, nullptr, nullptr,
                         G_DBUS_CALL_FLAGS_NONE, -1, nullptr, nullptr, nullptr);
}

void emit(const char* path, const char* iface, const char* signal, GVariant* params) {
  g_dbus_connection_emit_signal(L.conn, nullptr, path, iface, signal, params, nullptr);
}

// -- lifetime -----------------------------------------------------------------

gboolean on_exit_timeout(gpointer) {
  L.exit_source = 0;
  if (L.windows->len == 0) {
    g_debug("clide loader: no windows left, exiting");
    g_main_loop_quit(L.loop);
  }
  return G_SOURCE_REMOVE;
}

void schedule_exit(guint seconds) {
  if (L.exit_source != 0) g_source_remove(L.exit_source);
  L.exit_source = g_timeout_add_seconds(seconds, on_exit_timeout, nullptr);
}

void cancel_exit() {
  if (L.exit_source == 0) return;
  g_source_remove(L.exit_source);
  L.exit_source = 0;
}

// -- menu (com.canonical.dbusmenu) -------------------------------------------

GVariant* item_props(gint32 id) {
  GVariantBuilder b;
  g_variant_builder_init(&b, G_VARIANT_TYPE("a{sv}"));
  if (id == kSeparatorAId || id == kSeparatorBId) {
    g_variant_builder_add(&b, "{sv}", "type", g_variant_new_string("separator"));
    return g_variant_builder_end(&b);
  }
  const char* text = nullptr;
  g_autofree gchar* window_text = nullptr;
  if (id == kShowAllId) {
    text = label("showAll", "Show all windows");
  } else if (id == kHideAllId) {
    text = label("hideAll", "Hide all windows");
  } else if (id == kQuitAllId) {
    text = label("quitAll", "Quit clide");
  } else if (LoaderWindow* w = window_by_id(id)) {
    if (w->workspace != nullptr && *w->workspace != '\0') {
      window_text = g_path_get_basename(w->workspace);
      text = window_text;
    } else {
      text = label("noWorkspace", "clide (no project)");
    }
  }
  g_variant_builder_add(&b, "{sv}", "label", g_variant_new_string(text != nullptr ? text : ""));
  g_variant_builder_add(&b, "{sv}", "enabled", g_variant_new_boolean(TRUE));
  g_variant_builder_add(&b, "{sv}", "visible", g_variant_new_boolean(TRUE));
  return g_variant_builder_end(&b);
}

GVariant* menu_node(gint32 id) {
  return g_variant_new("(i@a{sv}@av)", id, item_props(id), g_variant_new_array(G_VARIANT_TYPE_VARIANT, nullptr, 0));
}

// Every id in display order: one row per window, then the fixed actions.
GArray* menu_ids() {
  GArray* ids = g_array_new(FALSE, FALSE, sizeof(gint32));
  for (guint i = 0; i < L.windows->len; i++) {
    g_array_append_val(ids, ((LoaderWindow*)g_ptr_array_index(L.windows, i))->id);
  }
  if (L.windows->len > 0) {
    gint32 sep = kSeparatorAId;
    g_array_append_val(ids, sep);
  }
  gint32 fixed[] = {kShowAllId, kHideAllId, kSeparatorBId, kQuitAllId};
  g_array_append_vals(ids, fixed, G_N_ELEMENTS(fixed));
  return ids;
}

GVariant* menu_layout() {
  g_autoptr(GArray) ids = menu_ids();
  GVariantBuilder children;
  g_variant_builder_init(&children, G_VARIANT_TYPE("av"));
  for (guint i = 0; i < ids->len; i++) {
    g_variant_builder_add(&children, "v", menu_node(g_array_index(ids, gint32, i)));
  }
  GVariantBuilder root;
  g_variant_builder_init(&root, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&root, "{sv}", "children-display", g_variant_new_string("submenu"));
  return g_variant_new("(i@a{sv}@av)", 0, g_variant_builder_end(&root), g_variant_builder_end(&children));
}

void menu_changed() {
  L.menu_revision++;
  emit(kMenuPath, "com.canonical.dbusmenu", "LayoutUpdated", g_variant_new("(ui)", L.menu_revision, 0));
}

GVariant* empty_ints() { return g_variant_new_array(G_VARIANT_TYPE_INT32, nullptr, 0); }

void show_all() {
  for (guint i = 0; i < L.windows->len; i++) call_window((LoaderWindow*)g_ptr_array_index(L.windows, i), "Show");
}

void hide_all() {
  for (guint i = 0; i < L.windows->len; i++) call_window((LoaderWindow*)g_ptr_array_index(L.windows, i), "Hide");
}

void quit_all() {
  for (guint i = 0; i < L.windows->len; i++) call_window((LoaderWindow*)g_ptr_array_index(L.windows, i), "Quit");
  // The windows unregister as they exit; the idle timer then ends the loader.
  // If one hangs, don't keep the icon up on its behalf.
  schedule_exit(kIdleExitSeconds + 2);
}

void menu_clicked(gint32 id) {
  if (id == kShowAllId) {
    show_all();
  } else if (id == kHideAllId) {
    hide_all();
  } else if (id == kQuitAllId) {
    quit_all();
  } else if (LoaderWindow* w = window_by_id(id)) {
    call_window(w, "Show");
  }
}

void on_menu_call(GDBusConnection*, const char*, const char*, const char*, const char* method, GVariant* params,
                  GDBusMethodInvocation* inv, gpointer) {
  if (g_strcmp0(method, "GetLayout") == 0) {
    g_dbus_method_invocation_return_value(inv, g_variant_new("(u@(ia{sv}av))", L.menu_revision, menu_layout()));
  } else if (g_strcmp0(method, "GetGroupProperties") == 0) {
    g_autoptr(GVariant) wanted = g_variant_get_child_value(params, 0);
    GVariantBuilder b;
    g_variant_builder_init(&b, G_VARIANT_TYPE("a(ia{sv})"));
    gsize n = g_variant_n_children(wanted);
    g_autoptr(GArray) all = menu_ids();
    GArray* ids = all;
    g_autoptr(GArray) asked = nullptr;
    if (n > 0) {
      asked = g_array_new(FALSE, FALSE, sizeof(gint32));
      for (gsize i = 0; i < n; i++) {
        gint32 id;
        g_variant_get_child(wanted, i, "i", &id);
        g_array_append_val(asked, id);
      }
      ids = asked;
    }
    for (guint i = 0; i < ids->len; i++) {
      gint32 id = g_array_index(ids, gint32, i);
      g_variant_builder_add(&b, "(i@a{sv})", id, item_props(id));
    }
    g_dbus_method_invocation_return_value(inv, g_variant_new("(@a(ia{sv}))", g_variant_builder_end(&b)));
  } else if (g_strcmp0(method, "GetProperty") == 0) {
    gint32 id;
    const char* name;
    g_variant_get(params, "(i&s)", &id, &name);
    g_autoptr(GVariant) props = item_props(id);
    g_autoptr(GVariant) v = g_variant_lookup_value(props, name, nullptr);
    if (v == nullptr) {
      g_dbus_method_invocation_return_dbus_error(inv, "com.canonical.dbusmenu.Error", "no such property");
      return;
    }
    g_dbus_method_invocation_return_value(inv, g_variant_new("(v)", v));
  } else if (g_strcmp0(method, "Event") == 0) {
    gint32 id;
    const char* event_id;
    g_variant_get(params, "(i&svu)", &id, &event_id, nullptr, nullptr);
    if (g_strcmp0(event_id, "clicked") == 0) menu_clicked(id);
    g_dbus_method_invocation_return_value(inv, nullptr);
  } else if (g_strcmp0(method, "EventGroup") == 0) {
    GVariantIter* it;
    g_variant_get(params, "(a(isvu))", &it);
    gint32 id;
    const char* event_id;
    while (g_variant_iter_loop(it, "(i&svu)", &id, &event_id, nullptr, nullptr)) {
      if (g_strcmp0(event_id, "clicked") == 0) menu_clicked(id);
    }
    g_variant_iter_free(it);
    g_dbus_method_invocation_return_value(inv, g_variant_new("(@ai)", empty_ints()));
  } else if (g_strcmp0(method, "AboutToShow") == 0) {
    g_dbus_method_invocation_return_value(inv, g_variant_new("(b)", FALSE));
  } else if (g_strcmp0(method, "AboutToShowGroup") == 0) {
    g_dbus_method_invocation_return_value(inv, g_variant_new("(@ai@ai)", empty_ints(), empty_ints()));
  } else {
    g_dbus_method_invocation_return_dbus_error(inv, "org.freedesktop.DBus.Error.UnknownMethod", method);
  }
}

GVariant* on_menu_get(GDBusConnection*, const char*, const char*, const char*, const char* prop, GError**, gpointer) {
  if (g_strcmp0(prop, "Version") == 0) return g_variant_new_uint32(3);
  if (g_strcmp0(prop, "TextDirection") == 0) return g_variant_new_string("ltr");
  if (g_strcmp0(prop, "Status") == 0) return g_variant_new_string("normal");
  if (g_strcmp0(prop, "IconThemePath") == 0) return g_variant_new_strv(nullptr, 0);
  return nullptr;
}

const char kMenuIntrospection[] =
    "<node><interface name='com.canonical.dbusmenu'>"
    "<property name='Version' type='u' access='read'/>"
    "<property name='TextDirection' type='s' access='read'/>"
    "<property name='Status' type='s' access='read'/>"
    "<property name='IconThemePath' type='as' access='read'/>"
    "<method name='GetLayout'><arg type='i' direction='in'/><arg type='i' direction='in'/>"
    "<arg type='as' direction='in'/><arg type='u' direction='out'/><arg type='(ia{sv}av)' direction='out'/></method>"
    "<method name='GetGroupProperties'><arg type='ai' direction='in'/><arg type='as' direction='in'/>"
    "<arg type='a(ia{sv})' direction='out'/></method>"
    "<method name='GetProperty'><arg type='i' direction='in'/><arg type='s' direction='in'/>"
    "<arg type='v' direction='out'/></method>"
    "<method name='Event'><arg type='i' direction='in'/><arg type='s' direction='in'/>"
    "<arg type='v' direction='in'/><arg type='u' direction='in'/></method>"
    "<method name='EventGroup'><arg type='a(isvu)' direction='in'/><arg type='ai' direction='out'/></method>"
    "<method name='AboutToShow'><arg type='i' direction='in'/><arg type='b' direction='out'/></method>"
    "<method name='AboutToShowGroup'><arg type='ai' direction='in'/><arg type='ai' direction='out'/>"
    "<arg type='ai' direction='out'/></method>"
    "<signal name='ItemsPropertiesUpdated'><arg type='a(ia{sv})'/><arg type='a(ias)'/></signal>"
    "<signal name='LayoutUpdated'><arg type='u'/><arg type='i'/></signal>"
    "<signal name='ItemActivationRequested'><arg type='i'/><arg type='u'/></signal>"
    "</interface></node>";

// -- status notifier item -----------------------------------------------------

// The tray mark: the clide logo (`< />`), monochrome — the same mark the
// in-app ClideSpinner tints and spins. A pixmap sits on the *panel*, whose
// colours the loader can't know (clide's theme doesn't apply there), so the
// mark is light with a thin dark halo: legible on light and dark panels alike.
constexpr guchar kMarkRgb[3] = {0xf2, 0xf2, 0xf5};
constexpr guchar kHaloRgb[3] = {0x14, 0x14, 0x1c};

// Alpha of the mark after cropping the logo's generous canvas padding to the
// strokes' bounding box, squared and with a small margin — uncropped, the
// mark reads tiny in a 22px tray slot.
GdkPixbuf* crop_to_mark(GdkPixbuf* src) {
  const int w = gdk_pixbuf_get_width(src), h = gdk_pixbuf_get_height(src);
  const int stride = gdk_pixbuf_get_rowstride(src);
  const guchar* px = gdk_pixbuf_read_pixels(src);
  int x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (px[y * stride + x * 4 + 3] > 8) {
        x0 = MIN(x0, x);
        y0 = MIN(y0, y);
        x1 = MAX(x1, x);
        y1 = MAX(y1, y);
      }
    }
  }
  if (x1 < 0) return GDK_PIXBUF(g_object_ref(src));
  const int side = MAX(x1 - x0, y1 - y0) + 1;
  const int margin = side / 10;
  const int full = side + 2 * margin;
  const int cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  GdkPixbuf* out = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8, full, full);
  gdk_pixbuf_fill(out, 0x00000000);
  // Copy the overlapping region so a mark near the canvas edge can't read out of bounds.
  const int dx = full / 2 - cx, dy = full / 2 - cy;
  const int sx = MAX(0, -dx), sy = MAX(0, -dy);
  const int ex = MIN(w, full - dx), ey = MIN(h, full - dy);
  if (ex > sx && ey > sy) gdk_pixbuf_copy_area(src, sx, sy, ex - sx, ey - sy, out, sx + dx, sy + dy);
  return out;
}

// SNI pixmaps are ARGB32 in network byte order, one per size; the host picks.
GVariant* load_icon_pixmaps() {
  GVariantBuilder b;
  g_variant_builder_init(&b, G_VARIANT_TYPE("a(iiay)"));
  g_autofree gchar* path =
      g_build_filename(L.exe_dir, "data", "flutter_assets", "assets", "logo", "logo-192.png", nullptr);
  g_autoptr(GError) error = nullptr;
  g_autoptr(GdkPixbuf) raw = gdk_pixbuf_new_from_file(path, &error);
  if (raw == nullptr) {
    // An empty pixmap list renders as an invisible icon — say why.
    g_warning("clide loader: no tray icon at %s: %s", path, error->message);
    return g_variant_ref_sink(g_variant_builder_end(&b));
  }
  g_autoptr(GdkPixbuf) with_alpha = gdk_pixbuf_add_alpha(raw, FALSE, 0, 0, 0);
  g_autoptr(GdkPixbuf) source = crop_to_mark(with_alpha);
  for (int size : {22, 32, 48, 64, 128}) {
    g_autoptr(GdkPixbuf) pb = gdk_pixbuf_scale_simple(source, size, size, GDK_INTERP_HYPER);
    if (pb == nullptr) continue;
    const int stride = gdk_pixbuf_get_rowstride(pb);
    const guchar* px = gdk_pixbuf_read_pixels(pb);
    const int r = MAX(1, size / 22);  // halo radius: one pixel at tray size
    guchar* argb = (guchar*)g_malloc((gsize)size * size * 4);
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        const double a = px[y * stride + x * 4 + 3] / 255.0;
        // Halo = the mark's alpha dilated by r.
        double halo = 0;
        for (int yy = MAX(0, y - r); yy <= MIN(size - 1, y + r); yy++) {
          for (int xx = MAX(0, x - r); xx <= MIN(size - 1, x + r); xx++) {
            halo = MAX(halo, px[yy * stride + xx * 4 + 3] / 255.0);
          }
        }
        // Mark over halo.
        const double h = halo * (1 - a);
        const double out = a + h;
        guchar* d = argb + ((gsize)y * size + x) * 4;
        d[0] = (guchar)(out * 255 + 0.5);
        for (int c = 0; c < 3; c++) {
          d[1 + c] = out > 0 ? (guchar)((kMarkRgb[c] * a + kHaloRgb[c] * h) / out + 0.5) : 0;
        }
      }
    }
    GVariant* bytes =
        g_variant_new_from_data(G_VARIANT_TYPE("ay"), argb, (gsize)size * size * 4, TRUE, g_free, argb);
    g_variant_builder_add(&b, "(ii@ay)", size, size, bytes);
  }
  return g_variant_ref_sink(g_variant_builder_end(&b));
}

// -- named icon + the notification spin ---------------------------------------
//
// The tray icon is served by name from a tiny icon theme the loader writes to
// $XDG_RUNTIME_DIR, built from the bundled symbolic mark (assets/tray). By
// name, KDE applies its colour scheme to the SVG, so the mark matches the
// panel like Plasma's own tray icons. The same theme holds the frames of one
// Y-axis turn — the in-app ClideSpinner's motion — which Pulse() flips
// through once when a notification is raised.

// Named so a failed lookup can't land on the colour app icon: freedesktop
// lookup strips dash-suffixes on a miss, and "clide-tray" fell back to the
// installed "clide" icon. "-symbolic" also marks it recolourable to GNOME.
constexpr char kIconName[] = "clidetray-symbolic";
constexpr int kSpinFrames = 16;
constexpr guint kSpinFrameMs = 45;  // ~0.7s for the turn
constexpr double kViewBoxCenterX = 80;  // centre of clide-tray.svg's viewBox

gchar* spin_frame_names[kSpinFrames] = {};

constexpr char kIndexTheme[] =
    "[Icon Theme]\nName=Hicolor\nDirectories=scalable/apps\n\n"
    "[scalable/apps]\nSize=22\nMinSize=8\nMaxSize=512\nType=Scalable\nContext=Applications\n";

gboolean write_file(const char* dir, const char* name, const char* contents) {
  g_autofree gchar* path = g_build_filename(dir, name, nullptr);
  g_autoptr(GError) error = nullptr;
  if (g_file_set_contents(path, contents, -1, &error)) return TRUE;
  g_warning("clide loader: could not write %s: %s", path, error->message);
  return FALSE;
}

// Returns FALSE when the named icon can't be set up; the pixmap then serves.
gboolean write_icon_theme() {
  g_autofree gchar* src =
      g_build_filename(L.exe_dir, "data", "flutter_assets", "assets", "tray", "clide-tray.svg", nullptr);
  g_autofree gchar* svg = nullptr;
  if (!g_file_get_contents(src, &svg, nullptr, nullptr)) {
    g_warning("clide loader: no tray mark at %s", src);
    return FALSE;
  }
  // Frames wrap the drawing (everything from the first <g to </svg>) in a
  // horizontal scale about the viewBox centre — a turn seen edge-on.
  const char* body = strstr(svg, "<g");
  const char* end = g_strrstr(svg, "</svg>");
  if (body == nullptr || end == nullptr || end < body) return FALSE;
  g_autofree gchar* head = g_strndup(svg, body - svg);
  g_autofree gchar* drawing = g_strndup(body, end - body);

  // Plasma derives the app name from an IconThemePath ending in "icons" and
  // looks both at that directory's root and in a theme layout below it, so
  // every icon is written to both.
  g_autofree gchar* dir = g_build_filename(g_get_user_runtime_dir(), "clide", "tray", "icons", nullptr);
  g_autofree gchar* apps = g_build_filename(dir, "hicolor", "scalable", "apps", nullptr);
  if (g_mkdir_with_parents(apps, 0700) != 0) return FALSE;
  g_autofree gchar* hicolor = g_build_filename(dir, "hicolor", nullptr);
  if (!write_file(hicolor, "index.theme", kIndexTheme)) return FALSE;
  auto write_icon = [&](const char* name, const char* contents) {
    g_autofree gchar* file = g_strdup_printf("%s.svg", name);
    return write_file(apps, file, contents) && write_file(dir, file, contents);
  };
  if (!write_icon(kIconName, svg)) return FALSE;

  for (int i = 0; i < kSpinFrames; i++) {
    double s = cos(2 * G_PI * i / kSpinFrames);
    if (fabs(s) < 0.06) s = s < 0 ? -0.06 : 0.06;  // never fully edge-on: a vanished icon reads as a glitch
    g_autofree gchar* frame = g_strdup_printf(
        "%s<g transform=\"translate(%g 0) scale(%.3f 1) translate(%g 0)\">%s</g></svg>\n", head, kViewBoxCenterX,
        s, -kViewBoxCenterX, drawing);
    spin_frame_names[i] = g_strdup_printf("clidetray-spin%02d-symbolic", i);
    if (!write_icon(spin_frame_names[i], frame)) return FALSE;
  }
  L.icon_theme_dir = g_strdup(dir);
  L.icon_name = kIconName;
  return TRUE;
}

void set_icon_name(const char* name) {
  L.icon_name = name;
  emit(kItemPath, "org.kde.StatusNotifierItem", "NewIcon", nullptr);
}

gboolean on_spin_tick(gpointer) {
  if (++L.spin_frame >= kSpinFrames) {
    L.spin_source = 0;
    set_icon_name(kIconName);
    return G_SOURCE_REMOVE;
  }
  set_icon_name(spin_frame_names[L.spin_frame]);
  return G_SOURCE_CONTINUE;
}

// One turn. A pulse while spinning is absorbed rather than restarting — a
// burst of notifications reads as one spin, not a stutter.
void pulse() {
  if (L.icon_theme_dir == nullptr || L.spin_source != 0) return;
  L.spin_frame = 0;
  L.spin_source = g_timeout_add(kSpinFrameMs, on_spin_tick, nullptr);
}

void toggle_windows() {
  gboolean any_hidden = FALSE;
  for (guint i = 0; i < L.windows->len; i++) {
    if (!((LoaderWindow*)g_ptr_array_index(L.windows, i))->visible) any_hidden = TRUE;
  }
  if (any_hidden || L.windows->len == 0) {
    show_all();
  } else {
    hide_all();
  }
}

void on_item_call(GDBusConnection*, const char*, const char*, const char*, const char* method, GVariant*,
                  GDBusMethodInvocation* inv, gpointer) {
  // Left-click toggles; middle-click shows. The context menu comes from the
  // host reading our Menu path, so ContextMenu/Scroll have nothing to do.
  if (g_strcmp0(method, "Activate") == 0) {
    toggle_windows();
  } else if (g_strcmp0(method, "SecondaryActivate") == 0) {
    show_all();
  }
  g_dbus_method_invocation_return_value(inv, nullptr);
}

GVariant* empty_pixmaps() { return g_variant_new_array(G_VARIANT_TYPE("(iiay)"), nullptr, 0); }

GVariant* on_item_get(GDBusConnection*, const char*, const char*, const char*, const char* prop, GError**, gpointer) {
  const char* title = label("tooltip", "clide");
  if (g_strcmp0(prop, "Category") == 0) return g_variant_new_string("ApplicationStatus");
  if (g_strcmp0(prop, "Id") == 0) return g_variant_new_string("clide");
  if (g_strcmp0(prop, "Title") == 0) return g_variant_new_string(title);
  if (g_strcmp0(prop, "Status") == 0) return g_variant_new_string("Active");
  if (g_strcmp0(prop, "WindowId") == 0) return g_variant_new_int32(0);
  if (g_strcmp0(prop, "IconThemePath") == 0) return g_variant_new_string(L.icon_theme_dir ? L.icon_theme_dir : "");
  if (g_strcmp0(prop, "IconName") == 0) return g_variant_new_string(L.icon_name);
  if (g_strcmp0(prop, "IconPixmap") == 0) return g_variant_ref(L.icon_pixmaps);
  if (g_strcmp0(prop, "OverlayIconName") == 0) return g_variant_new_string("");
  if (g_strcmp0(prop, "OverlayIconPixmap") == 0) return empty_pixmaps();
  if (g_strcmp0(prop, "AttentionIconName") == 0) return g_variant_new_string("");
  if (g_strcmp0(prop, "AttentionIconPixmap") == 0) return empty_pixmaps();
  if (g_strcmp0(prop, "AttentionMovieName") == 0) return g_variant_new_string("");
  if (g_strcmp0(prop, "ToolTip") == 0) return g_variant_new("(s@a(iiay)ss)", "", empty_pixmaps(), title, "");
  if (g_strcmp0(prop, "ItemIsMenu") == 0) return g_variant_new_boolean(FALSE);
  if (g_strcmp0(prop, "Menu") == 0) return g_variant_new_object_path(kMenuPath);
  return nullptr;
}

const char kItemIntrospection[] =
    "<node><interface name='org.kde.StatusNotifierItem'>"
    "<property name='Category' type='s' access='read'/>"
    "<property name='Id' type='s' access='read'/>"
    "<property name='Title' type='s' access='read'/>"
    "<property name='Status' type='s' access='read'/>"
    "<property name='WindowId' type='i' access='read'/>"
    "<property name='IconThemePath' type='s' access='read'/>"
    "<property name='IconName' type='s' access='read'/>"
    "<property name='IconPixmap' type='a(iiay)' access='read'/>"
    "<property name='OverlayIconName' type='s' access='read'/>"
    "<property name='OverlayIconPixmap' type='a(iiay)' access='read'/>"
    "<property name='AttentionIconName' type='s' access='read'/>"
    "<property name='AttentionIconPixmap' type='a(iiay)' access='read'/>"
    "<property name='AttentionMovieName' type='s' access='read'/>"
    "<property name='ToolTip' type='(sa(iiay)ss)' access='read'/>"
    "<property name='ItemIsMenu' type='b' access='read'/>"
    "<property name='Menu' type='o' access='read'/>"
    "<method name='ContextMenu'><arg type='i' direction='in'/><arg type='i' direction='in'/></method>"
    "<method name='Activate'><arg type='i' direction='in'/><arg type='i' direction='in'/></method>"
    "<method name='SecondaryActivate'><arg type='i' direction='in'/><arg type='i' direction='in'/></method>"
    "<method name='Scroll'><arg type='i' direction='in'/><arg type='s' direction='in'/></method>"
    "<signal name='NewTitle'/><signal name='NewIcon'/><signal name='NewToolTip'/>"
    "<signal name='NewStatus'><arg type='s'/></signal>"
    "</interface></node>";

// -- tray availability --------------------------------------------------------

void set_tray_available(gboolean available) {
  if (available == L.tray_available) return;
  L.tray_available = available;
  emit(CLIDE_LOADER_OBJECT_PATH, CLIDE_LOADER_INTERFACE, "TrayAvailabilityChanged", g_variant_new("(b)", available));
}

void refresh_availability() { set_tray_available(L.watcher_present && L.host_registered); }

void on_host_registered_reply(GObject* src, GAsyncResult* res, gpointer) {
  g_autoptr(GVariant) reply = g_dbus_connection_call_finish(G_DBUS_CONNECTION(src), res, nullptr);
  // No readable property: trust the watcher's presence (some watchers omit it).
  L.host_registered = TRUE;
  if (reply != nullptr) {
    g_autoptr(GVariant) v = nullptr;
    g_variant_get(reply, "(v)", &v);
    if (v != nullptr && g_variant_is_of_type(v, G_VARIANT_TYPE_BOOLEAN)) L.host_registered = g_variant_get_boolean(v);
  }
  refresh_availability();
}

void register_with_watcher() {
  g_dbus_connection_call(L.conn, kWatcherName, kWatcherPath, kWatcherName, "RegisterStatusNotifierItem",
                         g_variant_new("(s)", L.item_bus_name), nullptr, G_DBUS_CALL_FLAGS_NONE, -1, nullptr, nullptr,
                         nullptr);
  g_dbus_connection_call(L.conn, kWatcherName, kWatcherPath, "org.freedesktop.DBus.Properties", "Get",
                         g_variant_new("(ss)", kWatcherName, "IsStatusNotifierHostRegistered"), G_VARIANT_TYPE("(v)"),
                         G_DBUS_CALL_FLAGS_NONE, -1, nullptr, on_host_registered_reply, nullptr);
}

void on_watcher_signal(GDBusConnection*, const char*, const char*, const char*, const char* signal, GVariant*,
                       gpointer) {
  if (g_strcmp0(signal, "StatusNotifierHostRegistered") == 0) {
    L.host_registered = TRUE;
  } else if (g_strcmp0(signal, "StatusNotifierHostUnregistered") == 0) {
    // Another host may remain; re-ask rather than assume.
    register_with_watcher();
    return;
  }
  refresh_availability();
}

void on_watcher_appeared(GDBusConnection*, const char*, const char*, gpointer) {
  L.watcher_present = TRUE;
  register_with_watcher();
}

void on_watcher_vanished(GDBusConnection*, const char*, gpointer) {
  L.watcher_present = FALSE;
  L.host_registered = FALSE;
  refresh_availability();
}

// -- the loader's own interface ----------------------------------------------

void on_window_vanished(GDBusConnection*, const char* name, gpointer) {
  g_debug("clide loader: window %s gone", name);
  for (guint i = 0; i < L.windows->len; i++) {
    LoaderWindow* w = (LoaderWindow*)g_ptr_array_index(L.windows, i);
    if (g_strcmp0(w->sender, name) == 0) {
      g_ptr_array_remove_index(L.windows, i);
      break;
    }
  }
  menu_changed();
  if (L.windows->len == 0) schedule_exit(kIdleExitSeconds);
}

void on_loader_call(GDBusConnection*, const char* sender, const char*, const char*, const char* method,
                    GVariant* params, GDBusMethodInvocation* inv, gpointer) {
  if (g_strcmp0(method, "Register") == 0 || g_strcmp0(method, "Update") == 0) {
    const char* workspace;
    gboolean visible;
    g_variant_get(params, "(&sb)", &workspace, &visible);
    LoaderWindow* w = window_by_sender(sender);
    if (w == nullptr) {
      w = g_new0(LoaderWindow, 1);
      w->id = L.next_window_id++;
      if (L.next_window_id >= kFirstFixedId) L.next_window_id = 1;  // ids only need to be unique among the live
      w->sender = g_strdup(sender);
      w->vanish_watch = g_bus_watch_name_on_connection(L.conn, sender, G_BUS_NAME_WATCHER_FLAGS_NONE, nullptr,
                                                       on_window_vanished, nullptr, nullptr);
      g_ptr_array_add(L.windows, w);
      cancel_exit();
    }
    g_free(w->workspace);
    w->workspace = g_strdup(workspace);
    w->visible = visible;
    menu_changed();
    if (g_strcmp0(method, "Register") == 0) {
      g_dbus_method_invocation_return_value(inv, g_variant_new("(b)", L.tray_available));
    } else {
      g_dbus_method_invocation_return_value(inv, nullptr);
    }
  } else if (g_strcmp0(method, "SetLabels") == 0) {
    GVariantIter* it;
    g_variant_get(params, "(a{ss})", &it);
    const char *k, *v;
    while (g_variant_iter_loop(it, "{&s&s}", &k, &v)) g_hash_table_replace(L.labels, g_strdup(k), g_strdup(v));
    g_variant_iter_free(it);
    menu_changed();
    emit(kItemPath, "org.kde.StatusNotifierItem", "NewTitle", nullptr);
    emit(kItemPath, "org.kde.StatusNotifierItem", "NewToolTip", nullptr);
    g_dbus_method_invocation_return_value(inv, nullptr);
  } else if (g_strcmp0(method, "QuitAll") == 0) {
    quit_all();
    g_dbus_method_invocation_return_value(inv, nullptr);
  } else if (g_strcmp0(method, "Pulse") == 0) {
    pulse();
    g_dbus_method_invocation_return_value(inv, nullptr);
  } else {
    g_dbus_method_invocation_return_dbus_error(inv, "org.freedesktop.DBus.Error.UnknownMethod", method);
  }
}

// -- startup ------------------------------------------------------------------

guint register_object(const char* xml, const char* path, GDBusInterfaceMethodCallFunc call,
                      GDBusInterfaceGetPropertyFunc get) {
  g_autoptr(GDBusNodeInfo) node = g_dbus_node_info_new_for_xml(xml, nullptr);
  const GDBusInterfaceVTable vtable = {call, get, nullptr, {nullptr}};
  return g_dbus_connection_register_object(L.conn, path, node->interfaces[0], &vtable, nullptr, nullptr, nullptr);
}

void start_tray() {
  register_object(kItemIntrospection, kItemPath, on_item_call, on_item_get);
  register_object(kMenuIntrospection, kMenuPath, on_menu_call, on_menu_get);
  L.item_bus_name = g_strdup_printf("org.kde.StatusNotifierItem-%d-1", (int)getpid());
  g_bus_own_name_on_connection(L.conn, L.item_bus_name, G_BUS_NAME_OWNER_FLAGS_NONE, nullptr, nullptr, nullptr,
                               nullptr);
  g_dbus_connection_signal_subscribe(L.conn, kWatcherName, kWatcherName, nullptr, kWatcherPath, nullptr,
                                     G_DBUS_SIGNAL_FLAGS_NONE, on_watcher_signal, nullptr, nullptr);
  L.watcher_watch = g_bus_watch_name_on_connection(L.conn, kWatcherName, G_BUS_NAME_WATCHER_FLAGS_NONE,
                                                   on_watcher_appeared, on_watcher_vanished, nullptr, nullptr);
}

void on_loader_name_acquired(GDBusConnection*, const char*, gpointer) {
  g_debug("clide loader: acquired %s", CLIDE_LOADER_BUS_NAME);
  start_tray();
  schedule_exit(kStartupExitSeconds);
}

void on_loader_name_lost(GDBusConnection*, const char*, gpointer) {
  // Another loader already owns the tray (or the bus went away) — nothing to do.
  g_debug("clide loader: %s owned elsewhere or bus lost, exiting", CLIDE_LOADER_BUS_NAME);
  g_main_loop_quit(L.loop);
}

gboolean on_sigterm(gpointer) {
  g_debug("clide loader: signalled, exiting");
  g_main_loop_quit(L.loop);
  return G_SOURCE_REMOVE;
}

}  // namespace

int clide_loader_run() {
  g_autoptr(GError) error = nullptr;
  L.conn = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (L.conn == nullptr) {
    g_warning("clide loader: no session bus: %s", error->message);
    return 1;
  }
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  L.exe_dir = exe != nullptr ? g_path_get_dirname(exe) : g_strdup(".");
  L.windows = g_ptr_array_new_with_free_func(window_free);
  L.labels = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
  L.icon_pixmaps = load_icon_pixmaps();
  write_icon_theme();
  L.loop = g_main_loop_new(nullptr, FALSE);

  register_object(kClideLoaderIntrospection, CLIDE_LOADER_OBJECT_PATH, on_loader_call, nullptr);
  g_bus_own_name_on_connection(L.conn, CLIDE_LOADER_BUS_NAME, G_BUS_NAME_OWNER_FLAGS_DO_NOT_QUEUE,
                               on_loader_name_acquired, on_loader_name_lost, nullptr, nullptr);
  g_unix_signal_add(SIGTERM, on_sigterm, nullptr);
  g_unix_signal_add(SIGINT, on_sigterm, nullptr);

  g_main_loop_run(L.loop);

  g_ptr_array_unref(L.windows);
  g_hash_table_unref(L.labels);
  g_variant_unref(L.icon_pixmaps);
  g_free(L.item_bus_name);
  g_free(L.icon_theme_dir);
  for (gchar*& name : spin_frame_names) g_clear_pointer(&name, g_free);
  g_free(L.exe_dir);
  g_main_loop_unref(L.loop);
  g_object_unref(L.conn);
  return 0;
}
