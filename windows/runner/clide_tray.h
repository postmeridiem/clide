// D-110: the tray on Windows — plumbing written without Windows hardware to
// run it on; exercise and refine there (T-593).
//
// Same shape as the Linux runner: one binary. `clide.exe --loader` is a
// headless process (no Flutter engine) that owns the single notification-area
// icon for every clide window process. It is single-instance through a named
// mutex and reachable through a hidden message-only window. Window processes
// find it with FindWindowEx (starting one when absent), register with
// WM_COPYDATA, and are driven back with a registered private message.
#ifndef RUNNER_CLIDE_TRAY_H_
#define RUNNER_CLIDE_TRAY_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <map>
#include <memory>
#include <optional>
#include <string>

// Runs the loader until its last window is gone. Returns the exit code; exits
// at once when another loader already holds the mutex.
int ClideTrayLoaderRun(HINSTANCE instance);

// The window process's half: serves the `clide/tray` channel, turns WM_CLOSE
// into a hide while the tray can bring the window back, and keeps the loader
// informed. One per FlutterWindow.
class ClideTrayBridge {
 public:
  ClideTrayBridge(flutter::BinaryMessenger* messenger, HWND window);
  ~ClideTrayBridge();

  // Offered every top-level window message first; a value means handled.
  std::optional<LRESULT> HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

 private:
  void OnChannelCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  HWND FindLoader() const;
  void EnsureLoader();
  void SendToLoader(ULONG_PTR kind, const std::wstring& payload);
  void Register();
  void SendLabels();
  void SetAvailable(bool available);
  void ShowWindowNow();
  bool HideWindowNow();
  void Quit();

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool close_to_tray_ = false;  // off until Dart pushes the setting
  bool tray_available_ = false;
  bool quitting_ = false;
  std::wstring workspace_;
  std::map<std::wstring, std::wstring> labels_;
  ULONGLONG last_spawn_ms_ = 0;
};

#endif  // RUNNER_CLIDE_TRAY_H_
