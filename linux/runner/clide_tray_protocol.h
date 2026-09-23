// D-110: the private D-Bus contract between clide window processes and the
// headless tray loader (`clide --loader`). Both sides live in this binary, so
// the contract is internal — but it crosses processes (and possibly two
// different clide builds, e.g. an installed release and a `make run` debug
// build sharing one loader), so keep it additive.
#ifndef CLIDE_TRAY_PROTOCOL_H_
#define CLIDE_TRAY_PROTOCOL_H_

// Single-instance name the loader owns (DO_NOT_QUEUE: a second loader exits).
#define CLIDE_LOADER_BUS_NAME APPLICATION_ID ".Loader"
#define CLIDE_LOADER_OBJECT_PATH "/net/schweitz/clide/Loader"
#define CLIDE_LOADER_INTERFACE "net.schweitz.clide.Loader"

// Each window process exports this on its own connection; the loader calls it
// on the window's unique bus name.
#define CLIDE_WINDOW_OBJECT_PATH "/net/schweitz/clide/Window"
#define CLIDE_WINDOW_INTERFACE "net.schweitz.clide.Window"

// Loader:
//   Register(s workspace, b visible) -> (b tray_available)
//   Update(s workspace, b visible)
//   SetLabels(a{ss} labels)
//   QuitAll()
//   Pulse()      — spin the icon once (a notification was raised)
//   signal TrayAvailabilityChanged(b available)
// Window:
//   Show()  Hide()  Quit()
static const char kClideLoaderIntrospection[] =
    "<node>"
    "  <interface name='" CLIDE_LOADER_INTERFACE "'>"
    "    <method name='Register'>"
    "      <arg type='s' name='workspace' direction='in'/>"
    "      <arg type='b' name='visible' direction='in'/>"
    "      <arg type='b' name='tray_available' direction='out'/>"
    "    </method>"
    "    <method name='Update'>"
    "      <arg type='s' name='workspace' direction='in'/>"
    "      <arg type='b' name='visible' direction='in'/>"
    "    </method>"
    "    <method name='SetLabels'>"
    "      <arg type='a{ss}' name='labels' direction='in'/>"
    "    </method>"
    "    <method name='QuitAll'/>"
    "    <method name='Pulse'/>"
    "    <signal name='TrayAvailabilityChanged'>"
    "      <arg type='b' name='available'/>"
    "    </signal>"
    "  </interface>"
    "</node>";

static const char kClideWindowIntrospection[] =
    "<node>"
    "  <interface name='" CLIDE_WINDOW_INTERFACE "'>"
    "    <method name='Show'/>"
    "    <method name='Hide'/>"
    "    <method name='Quit'/>"
    "  </interface>"
    "</node>";

#endif  // CLIDE_TRAY_PROTOCOL_H_
