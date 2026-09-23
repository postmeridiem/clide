// D-110: the tray on Windows. See clide_tray.h. Plumbing — written against
// the Win32 docs without a Windows machine to run it on (T-593).
#include "clide_tray.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <vector>

#include "resource.h"
#include "utils.h"

namespace {

// -- the private contract (both sides live in this binary) --------------------

constexpr wchar_t kLoaderMutex[] = L"Local\\net.schweitz.clide.Loader";
constexpr wchar_t kLoaderClass[] = L"ClideTrayLoader";

// WM_COPYDATA kinds, window -> loader. Payloads are UTF-16, NUL-separated.
constexpr ULONG_PTR kCopyRegister = 1;  // "<visible 0|1>\0<workspace>"
constexpr ULONG_PTR kCopyLabels = 2;    // "<key>\0<value>\0<key>\0<value>..."
constexpr ULONG_PTR kCopyQuitAll = 3;   // ""
constexpr ULONG_PTR kCopyPulse = 4;     // ""

// Loader -> window, posted with the command in WPARAM.
constexpr WPARAM kCmdShow = 1;
constexpr WPARAM kCmdHide = 2;
constexpr WPARAM kCmdQuit = 3;
constexpr WPARAM kCmdAvailable = 4;  // LPARAM: 0/1

UINT CommandMessage() {
  static UINT id = RegisterWindowMessageW(L"net.schweitz.clide.tray.command");
  return id;
}

std::wstring Utf16FromUtf8(const std::string& s) {
  if (s.empty()) return {};
  int n = MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), nullptr, 0);
  std::wstring out(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), out.data(), n);
  return out;
}

std::vector<std::wstring> SplitNul(const wchar_t* data, size_t chars) {
  std::vector<std::wstring> parts;
  std::wstring cur;
  for (size_t i = 0; i < chars; i++) {
    if (data[i] == L'\0') {
      parts.push_back(cur);
      cur.clear();
    } else {
      cur.push_back(data[i]);
    }
  }
  if (!cur.empty()) parts.push_back(cur);
  return parts;
}

// -- loader -------------------------------------------------------------------

constexpr UINT kTrayCallback = WM_APP + 1;
constexpr UINT_PTR kIdleTimer = 1;
constexpr UINT_PTR kSpinTimer = 2;
constexpr UINT kIdleCheckMs = 1000;
constexpr int kIdleExitTicks = 3;       // seconds with no windows before exiting
constexpr int kStartupExitTicks = 20;   // a loader nobody registered with
constexpr UINT kSpinFrameMs = 45;
constexpr int kSpinFrames = 16;

constexpr UINT kMenuShowAll = 1000;
constexpr UINT kMenuHideAll = 1001;
constexpr UINT kMenuQuitAll = 1002;
constexpr UINT kMenuWindowBase = 1;  // + index into windows

struct LoaderWindow {
  HWND hwnd;
  bool visible;
  std::wstring workspace;
};

struct Loader {
  HWND msg_window = nullptr;
  NOTIFYICONDATAW icon{};
  bool icon_added = false;
  std::vector<LoaderWindow> windows;
  std::map<std::wstring, std::wstring> labels;
  int empty_ticks = 0;
  bool ever_registered = false;
  int spin_frame = 0;
  HICON base_icon = nullptr;
  UINT taskbar_created = 0;
} g_loader;

std::wstring Label(const wchar_t* key, const wchar_t* fallback) {
  auto it = g_loader.labels.find(key);
  return (it != g_loader.labels.end() && !it->second.empty()) ? it->second : fallback;
}

void Prune() {
  g_loader.windows.erase(std::remove_if(g_loader.windows.begin(), g_loader.windows.end(),
                                 [](const LoaderWindow& w) { return !IsWindow(w.hwnd); }),
                  g_loader.windows.end());
}

void PostToWindow(HWND hwnd, WPARAM cmd, LPARAM arg = 0) { PostMessageW(hwnd, CommandMessage(), cmd, arg); }

void BroadcastAvailability() {
  for (auto& w : g_loader.windows) PostToWindow(w.hwnd, kCmdAvailable, g_loader.icon_added ? 1 : 0);
}

void AddIcon() {
  g_loader.icon = {};
  g_loader.icon.cbSize = sizeof(g_loader.icon);
  g_loader.icon.hWnd = g_loader.msg_window;
  g_loader.icon.uID = 1;
  g_loader.icon.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  g_loader.icon.uCallbackMessage = kTrayCallback;
  g_loader.icon.hIcon = g_loader.base_icon;
  wcsncpy_s(g_loader.icon.szTip, Label(L"tooltip", L"clide").c_str(), _TRUNCATE);
  g_loader.icon_added = Shell_NotifyIconW(NIM_ADD, &g_loader.icon) != FALSE;
  if (g_loader.icon_added) {
    g_loader.icon.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &g_loader.icon);
  }
  BroadcastAvailability();
}

void ShowAll() {
  for (auto& w : g_loader.windows) PostToWindow(w.hwnd, kCmdShow);
}
void HideAll() {
  for (auto& w : g_loader.windows) PostToWindow(w.hwnd, kCmdHide);
}
void QuitAll() {
  for (auto& w : g_loader.windows) PostToWindow(w.hwnd, kCmdQuit);
}

void ToggleAll() {
  bool any_hidden = g_loader.windows.empty();
  for (auto& w : g_loader.windows) any_hidden = any_hidden || !w.visible;
  if (any_hidden) {
    ShowAll();
  } else {
    HideAll();
  }
}

void ShowMenu() {
  Prune();
  HMENU menu = CreatePopupMenu();
  for (size_t i = 0; i < g_loader.windows.size(); i++) {
    const auto& ws = g_loader.windows[i].workspace;
    std::wstring text = ws.empty() ? Label(L"noWorkspace", L"clide (no project)")
                                   : ws.substr(ws.find_last_of(L"\\/") == std::wstring::npos ? 0 : ws.find_last_of(L"\\/") + 1);
    AppendMenuW(menu, MF_STRING, kMenuWindowBase + i, text.c_str());
  }
  if (!g_loader.windows.empty()) AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kMenuShowAll, Label(L"showAll", L"Show all windows").c_str());
  AppendMenuW(menu, MF_STRING, kMenuHideAll, Label(L"hideAll", L"Hide all windows").c_str());
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kMenuQuitAll, Label(L"quitAll", L"Quit clide").c_str());

  POINT pt;
  GetCursorPos(&pt);
  // Required for the menu to dismiss when the user clicks elsewhere.
  SetForegroundWindow(g_loader.msg_window);
  UINT cmd = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON, pt.x, pt.y, 0, g_loader.msg_window, nullptr);
  DestroyMenu(menu);

  if (cmd == kMenuShowAll) {
    ShowAll();
  } else if (cmd == kMenuHideAll) {
    HideAll();
  } else if (cmd == kMenuQuitAll) {
    QuitAll();
  } else if (cmd >= kMenuWindowBase && cmd < kMenuWindowBase + g_loader.windows.size()) {
    PostToWindow(g_loader.windows[cmd - kMenuWindowBase].hwnd, kCmdShow);
  }
}

// One turn of the icon, horizontally squashed like the in-app ClideSpinner.
// Win32 has no cheap per-frame vector icon, so frames scale the base icon's
// bitmap; a pulse while spinning is absorbed.
void SpinFrame() {
  if (++g_loader.spin_frame >= kSpinFrames || !g_loader.icon_added) {
    KillTimer(g_loader.msg_window, kSpinTimer);
    g_loader.spin_frame = 0;
    g_loader.icon.hIcon = g_loader.base_icon;
    g_loader.icon.uFlags = NIF_ICON;
    if (g_loader.icon_added) Shell_NotifyIconW(NIM_MODIFY, &g_loader.icon);
    return;
  }
  const int size = GetSystemMetrics(SM_CXSMICON);
  double s = cos(2 * 3.14159265358979 * g_loader.spin_frame / kSpinFrames);
  int width = (int)(size * (s < 0 ? -s : s));
  if (width < 1) width = 1;
  HDC screen = GetDC(nullptr);
  HDC dc = CreateCompatibleDC(screen);
  BITMAPINFO bi{};
  bi.bmiHeader.biSize = sizeof(bi.bmiHeader);
  bi.bmiHeader.biWidth = size;
  bi.bmiHeader.biHeight = -size;
  bi.bmiHeader.biPlanes = 1;
  bi.bmiHeader.biBitCount = 32;
  void* bits = nullptr;
  HBITMAP color = CreateDIBSection(dc, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
  HBITMAP mask = CreateBitmap(size, size, 1, 1, nullptr);
  HGDIOBJ old = SelectObject(dc, color);
  // Mirrored on the far side of the turn, as a real rotation would show it.
  if (s < 0) {
    SetGraphicsMode(dc, GM_ADVANCED);
    XFORM flip{-1, 0, 0, 1, (FLOAT)size, 0};
    SetWorldTransform(dc, &flip);
  }
  DrawIconEx(dc, (size - width) / 2, 0, g_loader.base_icon, width, size, 0, nullptr, DI_NORMAL);
  SelectObject(dc, old);
  ICONINFO ii{TRUE, 0, 0, mask, color};
  HICON frame = CreateIconIndirect(&ii);
  DeleteObject(color);
  DeleteObject(mask);
  DeleteDC(dc);
  ReleaseDC(nullptr, screen);

  g_loader.icon.hIcon = frame;
  g_loader.icon.uFlags = NIF_ICON;
  Shell_NotifyIconW(NIM_MODIFY, &g_loader.icon);
  DestroyIcon(frame);  // the shell copies the icon
}

void Pulse() {
  if (!g_loader.icon_added || g_loader.spin_frame != 0) return;
  g_loader.spin_frame = 0;
  SetTimer(g_loader.msg_window, kSpinTimer, kSpinFrameMs, nullptr);
}

void OnCopyData(const COPYDATASTRUCT* cds, HWND sender) {
  const auto* data = static_cast<const wchar_t*>(cds->lpData);
  const size_t chars = cds->cbData / sizeof(wchar_t);
  switch (cds->dwData) {
    case kCopyRegister: {
      auto parts = SplitNul(data, chars);
      const bool visible = !parts.empty() && parts[0] == L"1";
      const std::wstring ws = parts.size() > 1 ? parts[1] : L"";
      auto it = std::find_if(g_loader.windows.begin(), g_loader.windows.end(), [&](const LoaderWindow& w) { return w.hwnd == sender; });
      if (it == g_loader.windows.end()) {
        g_loader.windows.push_back({sender, visible, ws});
        g_loader.ever_registered = true;
        g_loader.empty_ticks = 0;
      } else {
        it->visible = visible;
        it->workspace = ws;
      }
      PostToWindow(sender, kCmdAvailable, g_loader.icon_added ? 1 : 0);
      break;
    }
    case kCopyLabels: {
      auto parts = SplitNul(data, chars);
      for (size_t i = 0; i + 1 < parts.size(); i += 2) g_loader.labels[parts[i]] = parts[i + 1];
      if (g_loader.icon_added) {
        wcsncpy_s(g_loader.icon.szTip, Label(L"tooltip", L"clide").c_str(), _TRUNCATE);
        g_loader.icon.uFlags = NIF_TIP;
        Shell_NotifyIconW(NIM_MODIFY, &g_loader.icon);
      }
      break;
    }
    case kCopyQuitAll:
      QuitAll();
      break;
    case kCopyPulse:
      Pulse();
      break;
  }
}

LRESULT CALLBACK LoaderProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
  if (msg == g_loader.taskbar_created && g_loader.taskbar_created != 0) {
    AddIcon();  // Explorer restarted: the notification area forgot us
    return 0;
  }
  switch (msg) {
    case WM_COPYDATA:
      OnCopyData(reinterpret_cast<const COPYDATASTRUCT*>(lparam), reinterpret_cast<HWND>(wparam));
      return TRUE;
    case kTrayCallback:
      switch (LOWORD(lparam)) {
        case WM_LBUTTONUP:
        case NIN_SELECT:
        case NIN_KEYSELECT:
          ToggleAll();
          break;
        case WM_CONTEXTMENU:
        case WM_RBUTTONUP:
          ShowMenu();
          break;
      }
      return 0;
    case WM_TIMER:
      if (wparam == kSpinTimer) {
        SpinFrame();
      } else if (wparam == kIdleTimer) {
        Prune();
        g_loader.empty_ticks = g_loader.windows.empty() ? g_loader.empty_ticks + 1 : 0;
        if (g_loader.empty_ticks >= (g_loader.ever_registered ? kIdleExitTicks : kStartupExitTicks)) DestroyWindow(hwnd);
      }
      return 0;
    case WM_DESTROY:
      if (g_loader.icon_added) Shell_NotifyIconW(NIM_DELETE, &g_loader.icon);
      PostQuitMessage(0);
      return 0;
  }
  return DefWindowProcW(hwnd, msg, wparam, lparam);
}

// -- window side helpers ------------------------------------------------------

constexpr UINT_PTR kFindLoaderTimer = 0xC11DE;
constexpr ULONGLONG kRespawnBackoffMs = 5000;

}  // namespace

int ClideTrayLoaderRun(HINSTANCE instance) {
  HANDLE mutex = CreateMutexW(nullptr, TRUE, kLoaderMutex);
  if (mutex == nullptr || GetLastError() == ERROR_ALREADY_EXISTS) {
    if (mutex != nullptr) CloseHandle(mutex);
    return 0;  // another loader owns the tray
  }
  WNDCLASSW wc{};
  wc.lpfnWndProc = LoaderProc;
  wc.hInstance = instance;
  wc.lpszClassName = kLoaderClass;
  RegisterClassW(&wc);
  // Message-only: never shown, but FindWindowEx(HWND_MESSAGE, ...) finds it
  // and it receives the notification-area callbacks.
  g_loader.msg_window = CreateWindowExW(0, kLoaderClass, L"clide tray", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, instance, nullptr);
  if (g_loader.msg_window == nullptr) {
    CloseHandle(mutex);
    return 1;
  }
  g_loader.taskbar_created = RegisterWindowMessageW(L"TaskbarCreated");
  g_loader.base_icon = LoadIconW(instance, MAKEINTRESOURCEW(IDI_APP_ICON));
  AddIcon();
  SetTimer(g_loader.msg_window, kIdleTimer, kIdleCheckMs, nullptr);

  MSG msg;
  while (GetMessageW(&msg, nullptr, 0, 0)) {
    TranslateMessage(&msg);
    DispatchMessageW(&msg);
  }
  ReleaseMutex(mutex);
  CloseHandle(mutex);
  return 0;
}

// -- ClideTrayBridge ----------------------------------------------------------

ClideTrayBridge::ClideTrayBridge(flutter::BinaryMessenger* messenger, HWND window) : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "clide/tray", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) { OnChannelCall(call, std::move(result)); });
  char* no_tray = nullptr;
  size_t len = 0;
  const bool disabled = _dupenv_s(&no_tray, &len, "CLIDE_NO_TRAY") == 0 && no_tray != nullptr && strcmp(no_tray, "1") == 0;
  free(no_tray);
  if (!disabled) EnsureLoader();
}

ClideTrayBridge::~ClideTrayBridge() { KillTimer(window_, kFindLoaderTimer); }

HWND ClideTrayBridge::FindLoader() const { return FindWindowExW(HWND_MESSAGE, nullptr, kLoaderClass, nullptr); }

void ClideTrayBridge::EnsureLoader() {
  if (FindLoader() != nullptr) {
    Register();
    SendLabels();
    return;
  }
  const ULONGLONG now = GetTickCount64();
  if (last_spawn_ms_ == 0 || now - last_spawn_ms_ >= kRespawnBackoffMs) {
    last_spawn_ms_ = now;
    wchar_t exe[MAX_PATH];
    GetModuleFileNameW(nullptr, exe, MAX_PATH);
    std::wstring cmd = L"\"" + std::wstring(exe) + L"\" --loader";
    STARTUPINFOW si{sizeof(si)};
    PROCESS_INFORMATION pi{};
    if (CreateProcessW(nullptr, cmd.data(), nullptr, nullptr, FALSE, DETACHED_PROCESS | CREATE_NO_WINDOW, nullptr,
                       nullptr, &si, &pi)) {
      CloseHandle(pi.hThread);
      CloseHandle(pi.hProcess);
    }
  }
  // The loader registers its window asynchronously; look again shortly.
  SetTimer(window_, kFindLoaderTimer, 500, nullptr);
}

void ClideTrayBridge::SendToLoader(ULONG_PTR kind, const std::wstring& payload) {
  HWND loader = FindLoader();
  if (loader == nullptr) return;
  COPYDATASTRUCT cds{kind, (DWORD)(payload.size() * sizeof(wchar_t)), (PVOID)payload.data()};
  SendMessageTimeoutW(loader, WM_COPYDATA, reinterpret_cast<WPARAM>(window_), reinterpret_cast<LPARAM>(&cds),
                      SMTO_ABORTIFHUNG, 1000, nullptr);
}

void ClideTrayBridge::Register() {
  std::wstring payload = IsWindowVisible(window_) ? L"1" : L"0";
  payload.push_back(L'\0');
  payload += workspace_;
  SendToLoader(kCopyRegister, payload);
}

void ClideTrayBridge::SendLabels() {
  if (labels_.empty()) return;
  std::wstring payload;
  for (const auto& [k, v] : labels_) {
    payload += k;
    payload.push_back(L'\0');
    payload += v;
    payload.push_back(L'\0');
  }
  SendToLoader(kCopyLabels, payload);
}

void ClideTrayBridge::SetAvailable(bool available) {
  if (available == tray_available_) return;
  tray_available_ = available;
  channel_->InvokeMethod(
      "availability",
      std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{{flutter::EncodableValue("available"),
                                                                       flutter::EncodableValue(available)}}));
}

void ClideTrayBridge::ShowWindowNow() {
  ShowWindow(window_, SW_SHOW);
  if (IsIconic(window_)) ShowWindow(window_, SW_RESTORE);
  SetForegroundWindow(window_);
  Register();
}

bool ClideTrayBridge::HideWindowNow() {
  if (!tray_available_) return false;
  ShowWindow(window_, SW_HIDE);
  Register();
  return true;
}

void ClideTrayBridge::Quit() {
  quitting_ = true;
  PostMessageW(window_, WM_CLOSE, 0, 0);
}

std::optional<LRESULT> ClideTrayBridge::HandleMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == CommandMessage()) {
    switch (wparam) {
      case kCmdShow:
        ShowWindowNow();
        break;
      case kCmdHide:
        HideWindowNow();
        break;
      case kCmdQuit:
        Quit();
        break;
      case kCmdAvailable:
        SetAvailable(lparam != 0);
        break;
    }
    return 0;
  }
  switch (message) {
    case WM_TIMER:
      if (wparam == kFindLoaderTimer) {
        KillTimer(hwnd, kFindLoaderTimer);
        if (FindLoader() != nullptr) {
          Register();
          SendLabels();
        } else if (!quitting_) {
          EnsureLoader();
        }
        return 0;
      }
      break;
    case WM_CLOSE:
      if (!quitting_ && close_to_tray_ && HideWindowNow()) return 0;
      break;
  }
  return std::nullopt;
}

void ClideTrayBridge::OnChannelCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  const auto* args = call.arguments();
  if (method == "isAvailable") {
    result->Success(flutter::EncodableValue(tray_available_));
  } else if (method == "setCloseToTray") {
    const auto* b = args ? std::get_if<bool>(args) : nullptr;
    close_to_tray_ = b != nullptr && *b;
    result->Success(flutter::EncodableValue(true));
  } else if (method == "setWorkspace") {
    const auto* s = args ? std::get_if<std::string>(args) : nullptr;
    workspace_ = s ? Utf16FromUtf8(*s) : L"";
    Register();
    result->Success(flutter::EncodableValue(true));
  } else if (method == "setLabels") {
    if (const auto* map = args ? std::get_if<flutter::EncodableMap>(args) : nullptr) {
      for (const auto& [k, v] : *map) {
        const auto* ks = std::get_if<std::string>(&k);
        const auto* vs = std::get_if<std::string>(&v);
        if (ks && vs) labels_[Utf16FromUtf8(*ks)] = Utf16FromUtf8(*vs);
      }
    }
    SendLabels();
    result->Success(flutter::EncodableValue(true));
  } else if (method == "show") {
    ShowWindowNow();
    result->Success(flutter::EncodableValue(true));
  } else if (method == "hide") {
    result->Success(flutter::EncodableValue(HideWindowNow()));
  } else if (method == "quit") {
    result->Success(flutter::EncodableValue(true));
    Quit();
  } else if (method == "quitAll") {
    result->Success(flutter::EncodableValue(true));
    if (FindLoader() != nullptr) {
      SendToLoader(kCopyQuitAll, L"");
    } else {
      Quit();
    }
  } else if (method == "pulse") {
    SendToLoader(kCopyPulse, L"");
    result->Success(flutter::EncodableValue(FindLoader() != nullptr));
  } else {
    result->NotImplemented();
  }
}
