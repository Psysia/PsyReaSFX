// Isolated process-owned offscreen windows; never attaches to REAPER.
#include "platform/windows/win_dock_redraw.hpp"
#include <iostream>
#include <stdexcept>

static void require(bool ok, const char* message) {
  if (!ok) throw std::runtime_error(message);
}
static bool visible(HWND window) { return (GetWindowLongPtrW(window, GWL_STYLE) & WS_VISIBLE) != 0; }
static HWND make(HWND parent) {
  auto hwnd = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, L"STATIC", L"Dock redraw test",
    WS_VISIBLE | (parent ? WS_CHILD : WS_POPUP), -32000, -32000, 1, 1, parent, nullptr, nullptr, nullptr);
  require(hwnd != nullptr, "Cannot create test window");
  return hwnd;
}
int main() {
  HWND daw = nullptr;
  try {
    daw = make(nullptr);
    auto docker = make(daw), pane = make(docker), child = make(pane), sibling = make(pane);
    reaweb::WinDockRedraw first, second;
    first.sync(child); second.sync(sibling);
    // Repeated resize/state notifications must not change the hook boundary.
    for (int i = 0; i < 100; ++i) {
      first.sync(child);
      SendMessageW(daw, WM_SETREDRAW, FALSE, 0);
      require(!visible(daw), "Docked WebView intercepted DAW redraw suspension");
      SendMessageW(daw, WM_SETREDRAW, TRUE, 0);
      require(visible(daw), "DAW redraw did not resume");
    }
    SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
    require(visible(pane), "Lost Docker surface protection");
    SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
    first.detach();
    SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
    require(visible(pane), "Detaching one tab removed another tab's protection");
    SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
    second.detach();
    SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
    require(!visible(pane), "Last tab did not remove hooks");
    SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
    // Undocking must remove all hooks; direct top-level parenting adds none.
    first.sync(child);
    SetParent(child, daw); first.sync(child);
    SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
    require(!visible(pane), "Reparenting retained stale hooks");
    SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
    SendMessageW(daw, WM_SETREDRAW, FALSE, 0);
    require(!visible(daw), "Direct docking intercepted DAW redraw");
    SendMessageW(daw, WM_SETREDRAW, TRUE, 0);
    first.detach();
    DestroyWindow(daw);
    std::cout << "DAW batching, Docker surface, repeated sync, multiple tabs and detach passed\n";
    return 0;
  } catch (const std::exception& error) {
    if (daw) DestroyWindow(daw);
    std::cerr << error.what() << '\n';
    return 1;
  }
}
