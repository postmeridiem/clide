import Cocoa
import FlutterMacOS

/// D-110 close-to-Dock state, shared by the window and the app delegate. On
/// macOS the Dock is the tray: a closed window hides, the process keeps its
/// Claude sessions and terminals running, and a Dock click brings it back.
final class ClideDock {
  static let shared = ClideDock()

  /// Pushed from Dart (`app.closeToTray`). Off until then, so a close before
  /// the first frames quits as it always did.
  var closeToDock = false

  /// Set on a real quit, so closing windows on the way out isn't intercepted.
  var quitting = false

  /// Localized labels pushed from Dart (native has no catalog).
  var labels: [String: String] = [:]

  func label(_ key: String, _ fallback: String) -> String {
    if let v = labels[key], !v.isEmpty { return v }
    return fallback
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // The window object must survive being "closed" to the Dock.
    self.isReleasedWhenClosed = false

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  /// Every close path (the chrome's close button via `clide/window`, the
  /// traffic-light button, Cmd+W) lands here. While close-to-Dock is on, hide
  /// instead — the Dock is always there to bring the window back.
  override func close() {
    let dock = ClideDock.shared
    if dock.closeToDock && !dock.quitting {
      orderOut(nil)
      return
    }
    super.close()
  }
}
