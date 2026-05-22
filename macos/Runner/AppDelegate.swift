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
  }
}
