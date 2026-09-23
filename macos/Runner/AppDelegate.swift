import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // D-110: with close-to-Dock on, the last window closing only hides it, so
  // the app must not terminate with it.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return !ClideDock.shared.closeToDock
  }

  // D-110: a Dock click with the window hidden brings it back.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag { showMainWindow() }
    return true
  }

  // D-110: the Dock menu carries the "kill every window at once" action. Each
  // clide window is its own process (and its own Dock icon — the platform's
  // model), so Quit all reaches the other instances by bundle id.
  override func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()
    let quitAll = NSMenuItem(
      title: ClideDock.shared.label("quitAll", "Quit clide"),
      action: #selector(quitAllFromDock(_:)),
      keyEquivalent: "")
    quitAll.target = self
    menu.addItem(quitAll)
    return menu
  }

  @objc private func quitAllFromDock(_ sender: Any?) {
    quitAllInstances()
  }

  private func mainWindow() -> NSWindow? {
    return NSApp.windows.first { $0 is MainFlutterWindow } ?? NSApp.mainWindow ?? NSApp.windows.first
  }

  private func showMainWindow() {
    guard let window = mainWindow() else { return }
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Deferred a tick so a Dart caller gets its reply before the process goes.
  private func quitThisInstance() {
    ClideDock.shared.quitting = true
    DispatchQueue.main.async { NSApp.terminate(nil) }
  }

  private func quitAllInstances() {
    if let id = Bundle.main.bundleIdentifier {
      let me = ProcessInfo.processInfo.processIdentifier
      for app in NSRunningApplication.runningApplications(withBundleIdentifier: id)
      where app.processIdentifier != me {
        app.terminate()
      }
    }
    quitThisInstance()
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let window = NSApp.mainWindow ?? NSApp.windows.first,
          let flutterVC = window.contentViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "clide/window",
      binaryMessenger: flutterVC.engine.binaryMessenger)

    channel.setMethodCallHandler { (call, result) in
      guard let window = NSApp.mainWindow ?? NSApp.windows.first else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "pickDirectory":
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Open"
        panel.message = "Select a project folder"
        panel.beginSheetModal(for: window) { response in
          if response == .OK, let url = panel.url {
            result(url.path)
          } else {
            result(nil)
          }
        }
      case "startDrag":
        if let event = NSApp.currentEvent {
          window.performDrag(with: event)
        }
        result(nil)
      case "minimize":
        window.miniaturize(nil)
        result(nil)
      case "maximize":
        window.zoom(nil)
        result(nil)
      case "close":
        window.close()
        result(nil)
      case "isMaximized":
        result(window.isZoomed)
      case "startResize":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // T-138: native clipboard image/file reads. Flutter's built-in
    // clipboard is text-only; the composer turns a pasted file or image
    // into a Claude `@path` reference, which needs the non-text pasteboard
    // contents read here.
    let clipboardChannel = FlutterMethodChannel(
      name: "clide/clipboard",
      binaryMessenger: flutterVC.engine.binaryMessenger)

    clipboardChannel.setMethodCallHandler { (call, result) in
      let pasteboard = NSPasteboard.general
      switch call.method {
      case "readImage":
        if let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
          result(FlutterStandardTypedData(bytes: png))
        } else {
          result(nil)
        }
      case "readFiles":
        let urls = pasteboard.readObjects(
          forClasses: [NSURL.self],
          options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        result(urls.map { $0.path })
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // D-110: the tray channel. On macOS the Dock is always there, so the
    // window can always be brought back — availability is simply true.
    let trayChannel = FlutterMethodChannel(
      name: "clide/tray",
      binaryMessenger: flutterVC.engine.binaryMessenger)

    trayChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      let dock = ClideDock.shared
      switch call.method {
      case "isAvailable":
        result(true)
      case "setCloseToTray":
        dock.closeToDock = (call.arguments as? Bool) ?? false
        result(true)
      case "setWorkspace":
        // The Dock names the app, not the window; nothing to render.
        result(true)
      case "setLabels":
        if let labels = call.arguments as? [String: String] {
          dock.labels.merge(labels) { _, new in new }
        }
        result(true)
      case "show":
        self.showMainWindow()
        result(true)
      case "hide":
        self.mainWindow()?.orderOut(nil)
        result(true)
      case "quit":
        result(true)
        self.quitThisInstance()
      case "quitAll":
        result(true)
        self.quitAllInstances()
      case "pulse":
        // A notification was raised. The Dock's own idiom is a single bounce,
        // which macOS only shows while clide isn't frontmost.
        NSApp.requestUserAttention(.informationalRequest)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
