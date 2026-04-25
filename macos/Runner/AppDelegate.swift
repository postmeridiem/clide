import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
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
  }
}
