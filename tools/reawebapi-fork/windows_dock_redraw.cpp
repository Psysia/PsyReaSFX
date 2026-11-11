// Isolated process-owned offscreen windows; never attaches to REAPER.
#include "platform/windows/win_dock_redraw.hpp"
#include <iostream>
#include <memory>
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

// The custom host records the messages REAPER must be allowed to handle while
// changing its child tree. Visibility alone would miss a swallowed TRUE.
struct NativeRedraw {
  unsigned disabled = 0, enabled = 0;
};
static LRESULT CALLBACK record_redraw(HWND hwnd, UINT message, WPARAM wp, LPARAM lp, UINT_PTR, DWORD_PTR data) {
  auto& events = *reinterpret_cast<NativeRedraw*>(data);
  if (message == WM_SETREDRAW) {
    if (wp) ++events.enabled;
    else ++events.disabled;
  }
  return DefSubclassProc(hwnd, message, wp, lp);
}
struct RedrawObservation {
  HWND hwnd;
  RedrawObservation(HWND window, NativeRedraw& events) : hwnd(window) {
    require(SetWindowSubclass(hwnd, record_redraw, 1, reinterpret_cast<DWORD_PTR>(&events)) != FALSE,
      "Cannot observe native Docker redraw messages");
  }
  ~RedrawObservation() { RemoveWindowSubclass(hwnd, record_redraw, 1); }
};

static void transitions(HWND daw) {
  auto docker = make(daw), pane = make(docker), child = make(pane), sibling = make(pane);
  NativeRedraw events;
  RedrawObservation observation(pane, events);
  reaweb::WinDockRedraw first, second;
  first.sync(child); second.sync(sibling);
  // Establish the ordinary resize behavior: the old implementation also keeps
  // the host visible here, which is unsafe during a structural removal.
  SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
  require(visible(pane) && events.disabled == 0, "Ordinary resize protection changed");
  SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
  require(events.enabled == 0, "Intercepted resize enable leaked to host");

  {
    reaweb::WinDockRedraw::Transition transition(first);
    // The second tab still has a guard. It must not swallow the host's batch.
    SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
    require(!visible(pane) && events.disabled == 1, "Shared Docker swallowed transition disable");
    SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
    require(visible(pane) && events.enabled == 1, "Shared Docker swallowed transition enable");
  }
  SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
  require(visible(pane) && events.disabled == 1, "Resize protection did not resume");
  SendMessageW(pane, WM_SETREDRAW, TRUE, 0);

  // A host batch can span the end of the transition; neither the matching TRUE
  // nor repeated FALSE may be mistaken for a new protected resize operation.
  {
    reaweb::WinDockRedraw::Transition transition(first);
    SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
  }
  require(!visible(pane) && events.disabled == 2, "Transition destructor resumed an active host batch");
  ShowWindow(pane, SW_SHOWNA);
  SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
  require(!visible(pane) && events.disabled == 3, "Native batch continuation was intercepted");
  SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
  require(visible(pane) && events.enabled == 2, "Late host enable was intercepted");

  // Convert an already intercepted FALSE into native suspension at the
  // structural boundary. The original matching TRUE is still authoritative.
  SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
  require(visible(pane) && events.disabled == 3, "Expected an intercepted resize batch");
  {
    reaweb::WinDockRedraw::Transition transition(first);
    require(!visible(pane) && events.disabled == 4, "Outstanding intercepted disable was not forwarded");
  }
  require(!visible(pane), "Outstanding host batch resumed before its matching enable");
  SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
  require(visible(pane) && events.enabled == 3, "Converted disable lost its matching enable");

  {
    reaweb::WinDockRedraw::Transition outer(first);
    {
      reaweb::WinDockRedraw::Transition inner(second);
      SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
      SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
    }
    SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
    require(!visible(pane) && events.disabled == 6, "Nested transition released outer suspension");
  }
  SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
  require(visible(pane) && events.enabled == 5, "Nested transition lost late enable");
  SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
  require(visible(pane) && events.disabled == 6, "Nested transition retained suspension");
  SendMessageW(pane, WM_SETREDRAW, TRUE, 0);

  // Removing/reparenting every tab inside a transition must keep the token
  // valid until native cleanup has finished, including a late enable.
  {
    reaweb::WinDockRedraw::Transition transition(first);
    SetParent(child, daw); first.sync(child);
    second.detach();
    SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
    require(!visible(pane) && events.disabled == 7, "Detached transition lost native disable");
  }
  SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
  require(visible(pane) && events.enabled == 6, "Last-tab removal lost native enable");
  first.detach(); DestroyWindow(child);
  RemoveWindowSubclass(pane, record_redraw, 1);
  DestroyWindow(docker);
}

static void destroyed_hosts(HWND daw) {
  auto docker = make(daw), pane = make(docker), child = make(pane);
  auto guard = std::make_unique<reaweb::WinDockRedraw>();
  guard->sync(child);
  auto transition = std::make_unique<reaweb::WinDockRedraw::Transition>(*guard);
  SendMessageW(pane, WM_SETREDRAW, FALSE, 0);
  // Closing a docked window can destroy the guard before the enclosing host
  // operation releases its token. This must never retain a pointer to guard.
  guard.reset();
  SendMessageW(pane, WM_SETREDRAW, TRUE, 0);
  require(visible(pane), "Token outliving its guard lost native enable");
  DestroyWindow(docker);

  // Old tokens must not affect a new host, even after the old HWND tree died.
  // The token also checks record identity if Windows reuses an HWND value.
  auto replacement = make(daw), replacement_pane = make(replacement), replacement_child = make(replacement_pane);
  reaweb::WinDockRedraw replacement_guard;
  replacement_guard.sync(replacement_child);
  transition.reset();
  SendMessageW(replacement_pane, WM_SETREDRAW, FALSE, 0);
  require(visible(replacement_pane), "Destroyed-host token changed replacement guard");
  SendMessageW(replacement_pane, WM_SETREDRAW, TRUE, 0);
  replacement_guard.detach(); DestroyWindow(replacement);
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
    transitions(daw);
    destroyed_hosts(daw);
    DestroyWindow(daw);
    std::cout << "DAW batching, Docker surface, shared/nested structural transitions, late redraw enable, "
      "pending batch conversion, detach and destroyed-host lifetime passed\n";
    return 0;
  } catch (const std::exception& error) {
    if (daw) DestroyWindow(daw);
    std::cerr << error.what() << '\n';
    return 1;
  }
}
